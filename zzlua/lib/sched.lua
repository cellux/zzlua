local adt = require('adt')
local time = require('time')
local nn = require('nanomsg')
local msgpack = require('msgpack')
local inspect = require('inspect')

local sf = string.format

local M = {}

-- must be set to a platform-specific implementation at startup
M.poller_factory = nil

local module_constructors = {}

function M.register_module(mc)
   table.insert(module_constructors, mc)
end

local function ModuleRegistry(scheduler)
   local hooks = {
      init = {},
      tick = {},
      done = {},
   }
   for _,mc in ipairs(module_constructors) do
      local m = mc(scheduler)
      for k,_ in pairs(hooks) do
         if m[k] then
            table.insert(hooks[k], m[k])
         end
      end
   end
   local self = {}
   function self:invoke(hook)
      assert(hooks[hook])
      for _,fn in ipairs(hooks[hook]) do
         fn()
      end
   end
   return self
end

local scheduler_singleton

local OFF = {}
M.OFF = OFF

local function Scheduler()
   local self = {}

   local next_event_id = { -1, -1000 }

   function self.make_event_id(persistent)
      local index = persistent and 1 or 2
      local rv = next_event_id[index]
      next_event_id[index] = next_event_id[index] - 1
      -- naive attempt to handle wraparound
      if next_event_id[index] > 0 then
         if persistent then
            error("persistent event id overflow")
         else
            next_event_id[index] = -1000
         end
      end
      return rv
   end

   if not M.poller_factory then
      error("sched.poller_factory is not set")
   end

   local poller = M.poller_factory()

   function self.poll(fd, events)
      local event_id = self.make_event_id()
      poller:add(fd, events, event_id)
      local rv = self.wait(event_id)
      poller:del(fd, events, event_id)
      return rv
   end

   local module_registry = ModuleRegistry(self)

   local running = false

   -- runnable threads
   local runnable = adt.List()

   local function RunnableThread(t, data)
      return { t = t, data = data }
   end

   -- threads waiting for their time to come, ordered by wake-up time
   local sleeping = adt.OrderedList(function(st) return st.time end)

   local function SleepingThread(t, time)
      return { t = t, time = time }
   end

   -- threads waiting for an event to arrive
   -- key: thread, value: background thread? (true/false)
   local waiting = {}

   -- number of threads waiting in the foreground
   -- (foreground threads keep the event loop alive)
   local waiting_fg = 0

   local function add_waiting(t, is_background)
      assert(waiting[t] == nil)
      waiting[t] = is_background and true or false
      if not is_background then
         waiting_fg = waiting_fg + 1
      end
   end
   
   local function del_waiting(t)
      local is_background = waiting[t]
      assert(type(is_background) == 'boolean')
      waiting[t] = nil
      if not is_background then
         waiting_fg = waiting_fg - 1
      end
   end

   -- threads listening to various events
   -- key: evtype, value: array of threads waiting
   local listeners = {}

   local function add_listener(evtype, l)
      if not listeners[evtype] then
         listeners[evtype] = {}
      end
      table.insert(listeners[evtype], l)
   end

   local function del_listener(evtype, l)
      local ls = listeners[evtype]
      if ls then
         local i = 1
         while i <= #ls do
            if ls[i] == l then
               table.remove(ls, i)
            else
               i = i + 1
            end
         end
      end
   end

   function self.listen(evtype, t, is_background)
      assert(type(t)=='thread')
      add_listener(evtype, t)
      add_waiting(t, is_background)
   end

   function self.unlisten(evtype, t)
      assert(type(t)=='thread')
      del_listener(evtype, t)
      del_waiting(t)
   end

   local event_queue = adt.List()

   -- event_sub: the socket we receive events from
   local event_sub = nn.socket(nn.AF_SP, nn.SUB)
   nn.setsockopt(event_sub, nn.SUB, nn.SUB_SUBSCRIBE, "")
   local event_sub_id = nn.bind(event_sub, "inproc://events")

   -- a poller for event_sub (used when we wait for events)
   local event_sub_fd = nn.getsockopt(event_sub, 0, nn.RCVFD)
   local event_sub_id = self.make_event_id(true)

   -- tick: one iteration of the event loop
   local function tick() 
      local now = time.time()

      local function wakeup_sleepers(now)
         -- wake up sleeping threads whose time has come
         while sleeping:size() > 0 and sleeping[0].time <= now do
            local st = sleeping:shift()
            runnable:push(RunnableThread(st.t, nil))
         end
      end

      wakeup_sleepers(now)

      module_registry:invoke('tick')

      local function handle_poll_event(events, event_id)
         if event_id == event_sub_id then
            local event = nn.recv(event_sub)
            local unpacked = msgpack.unpack(event)
            assert(type(unpacked) == "table")
            assert(#unpacked == 2, "event shall be a table of two elements, but it is "..inspect(unpacked))
            event_queue:push(unpacked)
         else
            event_queue:push({event_id, events})
         end
      end

      local function poll_events()
         if runnable:size() == 0 and event_queue:empty() then
            -- there are no runnable threads, the event queue is empty
            -- we poll for events using a timeout to avoid busy-waiting
            local wait_until = now + 1 -- default timeout: 1 second
            if sleeping:size() > 0 then
               -- but may be shorter (or longer)
               -- if there are sleeping threads
               wait_until = sleeping[0].time
               -- if the thread's time comes sooner than 1 ms,
               -- we round up to 1 ms (the granularity of nn_poll)
               if wait_until - now < 0.001 then
                  wait_until = now + 0.001
               end
            end
            local timeout = wait_until - now
            poller:wait(timeout*1000, handle_poll_event)
         else
            -- there are runnable threads waiting for execution
            -- or the event queue is not empty
            --
            -- we poll in a non-blocking way
            poller:wait(0, handle_poll_event)
         end
      end

      -- poll for events, transfer them to the event queue
      poll_events()

      local function process_event(event)
         local evtype, evdata = unpack(event)
         --print(sf("got event: evtype=%s, evdata=%s", evtype, inspect(evdata)))
         if evtype == 'quit' then
            running = false
            -- after quit, only those threads shall be resumed which
            -- have registered for this event
            runnable:clear()
         end
         -- wake up threads waiting for this evtype
         local ls = listeners[evtype]
         if ls then
            for _,t in ipairs(ls) do
               runnable:push(RunnableThread(t, evdata))
               del_waiting(t)
            end
            -- clear all listeners after they got woken up.
            --
            -- they must re-register if they want to get notified
            -- again (this happens automatically for listeners
            -- registered with sched.on())
            listeners[evtype] = nil
         end
      end

      -- warning: do not try to process all events at once here
      --
      -- it won't work
      if not event_queue:empty() then
         local event = event_queue:shift()
         process_event(event)
      end

      local function resume_runnable()
         local runnable_next = adt.List()
         for rt in runnable:itervalues() do
            local t, data = rt.t, rt.data
            local ok, rv, is_background = coroutine.resume(t, data)
            local status = coroutine.status(t)
            if status == "suspended" then
               if type(rv) == "number" and rv > 0 then
                  -- the coroutine shall be resumed at the given time
                  sleeping:push(SleepingThread(t, rv))
               elseif rv then
                  -- rv is the evtype which shall wake up this thread
                  self.listen(rv, t, is_background)
               else
                  -- the coroutine shall be resumed in the next tick
                  runnable_next:push(RunnableThread(t, nil))
               end
            elseif status == "dead" then
               if not ok then
                  error(rv, 0)
               else
                  -- the coroutine finished its execution
               end
            else
               error(sf("unhandled status returned from coroutine.status(): %s", status))
            end
         end
         runnable = runnable_next
      end

      resume_runnable()
   end

   function self.loop()
      running = true
      repeat
         tick()
      until not running or
         (runnable:size() == 0
             and sleeping:size() == 0
             and waiting_fg == 0)
   end

   function self.sched(fn, data)
      if fn then
         -- add fn to the list of runnable threads
         runnable:push(RunnableThread(coroutine.create(fn), data))
      else
         -- enter the event loop, continue scheduling until there is
         -- work to do. when the event loop exits, cleanup and destroy
         -- this Scheduler instance.
         poller:add(event_sub_fd, "r", event_sub_id)
         module_registry:invoke('init')
         self.loop()
         module_registry:invoke('done')
         poller:del(event_sub_fd, "r", event_sub_id)
         poller:close()
         nn.close(event_sub)
         scheduler_singleton = nil
         -- after this function returns, we will be garbage-collected
      end
   end

   self.yield = coroutine.yield
   self.wait = coroutine.yield

   function self.sleep(seconds)
      return self.wait(time.time() + seconds)
   end

   local event_cb_threads = {}

   function self.on(evtype, callback)
      assert(event_cb_threads[callback] == nil, "registering the same callback for several event types is not supported")
      local function w()
         while true do
            local evdata = self.wait(evtype, true)
            if evdata == OFF or callback(evdata) == OFF then
               break
            end
         end
      end
      -- run w() until it waits (yields) for the first time
      local t = coroutine.create(w)
      local status, evtype, is_background = coroutine.resume(t)
      -- register the waiting thread as a background listener
      self.listen(evtype, t, true)
      -- this - admittedly cumbersome - implementation ensures that
      -- the callback will be primed when sched.on() returns
      event_cb_threads[callback] = t
   end

   function self.off(evtype, callback)
      local t = event_cb_threads[callback]
      assert(t)
      local status = coroutine.resume(t, OFF)
      assert(status)
      assert(coroutine.status(t)=="dead", sf("can't remove event handler, coroutine.status = %s (expected: dead)", coroutine.status(t)))
      self.unlisten(evtype, t)
      event_cb_threads[callback] = nil
   end

   function self.emit(evtype, evdata)
      assert(evdata ~= nil, "evdata must be non-nil")
      event_queue:push({ evtype, evdata })
   end

   function self.quit()
      self.emit('quit', 0)
   end

   return self
end

local function get_scheduler()
   if not scheduler_singleton then
      scheduler_singleton = Scheduler()
   end
   return scheduler_singleton
end

local M_mt = {}

-- all lookups are proxied to the singleton Scheduler instance
function M_mt:__index(k)
   return get_scheduler()[k]
end

function M_mt:__call(...)
   return get_scheduler().sched(...)
end

return setmetatable(M, M_mt)
