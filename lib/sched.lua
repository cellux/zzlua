local adt = require('adt')
local time = require('time')
local nn = require('nanomsg')
local msgpack = require('msgpack')
local inspect = require('inspect')

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

-- after sched.wait(t), math.abs(time.time()-t) is expected to be
-- less than sched.precision
M.precision = 0.001 -- seconds

local function Scheduler()
   local self = {}

   local next_event_id = -1

   function self.make_event_id()
      local rv = next_event_id
      next_event_id = next_event_id - 1
      -- TODO: find a way to ensure that this never blows up
      if next_event_id < -(2^31) then
         error("event id overflow")
      end
      return rv
   end

   if not M.poller_factory then
      error("sched.poller_factory is not set")
   end

   local poller = M.poller_factory()

   -- make it public so that people can add their fds for permanent polling
   self.poller = poller

   function self.poll(fd, events)
      events = events.."1" -- one shot
      local event_id = self.make_event_id()
      poller:add(fd, events, event_id)
      local rv = self.wait(event_id)
      poller:del(fd, events, event_id)
      return rv
   end

   local module_registry = ModuleRegistry(self)

   local running = false

   -- runnable threads:
   -- those which will be resumed in the current tick
   local runnables = adt.List()

   local function Runnable(r, data)
      return { r = r, data = data }
   end

   -- sleeping threads:
   -- waiting for their time to come, ordered by wake-up time
   local sleeping = adt.OrderedList(function(st) return st.time end)

   local function SleepingRunnable(r, time)
      return { r = r, time = time }
   end

   -- waiting:
   -- threads and callback functions waiting for various events
   --
   -- key: evtype, value: array of runnables and callbacks waiting
   --
   -- if it's a thread, it will be woken up
   --
   -- if it's a function, it will be wrapped into a handler thread
   -- which will be woken up
   --
   -- if it's a thread wrapped in a single-element table, it's a
   -- background thread (does not keep the event loop alive) ;
   -- otherwise it's handled in the same way as a plain thread
   --
   -- threads are removed once they have been serviced, callback
   -- functions remain
   local waiting = {}
   local n_waiting_threads = 0

   local function add_waiting(evtype, r) -- r for runnable
      if not waiting[evtype] then
         waiting[evtype] = adt.List()
      end
      waiting[evtype]:push(r)
      if type(r)=="thread" then
         n_waiting_threads = n_waiting_threads + 1
      end
   end

   local function del_waiting(evtype, r) -- r for runnable
      if waiting[evtype] then
         local rs = waiting[evtype]
         local i = rs:index(r)
         if i then
            rs:remove_at(i)
            if type(r)=="thread" then
               n_waiting_threads = n_waiting_threads - 1
            end
         end
         if waiting[evtype]:empty() then
            waiting[evtype] = nil
         end
      end
   end

   self.on = add_waiting
   self.off = del_waiting

   local event_queue = adt.List()

   -- event_sub: the socket we receive events from
   local event_sub = nn.socket(nn.AF_SP, nn.SUB)
   nn.setsockopt(event_sub, nn.SUB, nn.SUB_SUBSCRIBE, "")
   nn.bind(event_sub, "inproc://events")

   -- a poller for event_sub (used when we wait for events)
   local event_sub_fd = nn.getsockopt(event_sub, 0, nn.RCVFD)
   local event_sub_id = self.make_event_id()
   poller:add(event_sub_fd, "r", event_sub_id)

   -- tick: one iteration of the event loop
   local function tick() 
      local now = time.time()
      self.now = now

      local function wakeup_sleepers(now)
         -- wake up sleeping threads whose time has come
         while sleeping:size() > 0 and sleeping[0].time <= now do
            local sr = sleeping:shift()
            runnables:push(Runnable(sr.r, nil))
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
         if runnables:size() == 0 and event_queue:empty() then
            -- there are no runnable threads, the event queue is empty
            -- we poll for events using a timeout to avoid busy-waiting
            local wait_until = now + 1 -- default timeout: 1 second
            if sleeping:size() > 0 then
               -- but may be shorter (or longer)
               -- if there are sleeping threads
               wait_until = sleeping[0].time
            end
            local timeout_ms = (wait_until - now) * 1000 -- sec -> ms
            -- if the thread's time comes sooner than 1 ms,
            -- we round up to 1 ms (the granularity of epoll)
            if timeout_ms < 1 then
               timeout_ms = 1
            end
            -- round to a whole number
            timeout_ms = math.floor(timeout_ms+0.5)
            poller:wait(timeout_ms, handle_poll_event)
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
            -- are waiting for this evtype ('quit')
            runnables:clear()
         end
         -- wake up threads/callbacks waiting for this evtype
         local rs = waiting[evtype] -- runnables
         if rs then
            local rs_next = adt.List()
            for r in rs:itervalues() do
               if type(r)=="thread" then
                  -- threads will be resumed and then forgotten
                  runnables:push(Runnable(r, evdata))
                  n_waiting_threads = n_waiting_threads - 1
               elseif type(r)=="table" then
                  -- background threads are resumed and forgotten
                  runnables:push(Runnable(r, evdata))
               elseif type(r)=="function" then
                  -- callback functions are wrapped into a handler
                  -- thread which is then resumed
                  local function wrapper(evdata)
                     -- remove the callback if it returns sched.OFF
                     -- quit handlers are also automatically removed
                     if r(evdata) == OFF or evtype == 'quit' then
                        del_waiting(evtype, r)
                     end
                  end
                  self.sched(wrapper, evdata)
                  -- callbacks keep waiting
                  rs_next:push(r)
               else
                  ef("invalid object in waiting[%s]: %s", evtype, r)
               end
            end
            if rs_next:empty() then
               waiting[evtype] = nil
            else
               waiting[evtype] = rs_next
            end
         end
      end

      while not event_queue:empty() do
         local event = event_queue:shift()
         process_event(event)
      end

      local function resume_runnables()
         local runnables_next = adt.List()
         for runnable in runnables:itervalues() do
            local r, data = runnable.r, runnable.data
            local is_background = (type(r)=="table")
            local t = is_background and r[1] or r
            local ok, rv = coroutine.resume(t, data)
            local status = coroutine.status(t)
            if status == "suspended" then
               if type(rv) == "number" and rv > 0 then
                  -- the coroutine shall be resumed at the given time
                  sleeping:push(SleepingRunnable(r, rv))
               elseif rv then
                  -- rv is the evtype which shall wake up this thread
                  add_waiting(rv, r)
               else
                  -- the coroutine shall be resumed in the next tick
                  runnables_next:push(Runnable(r, nil))
               end
            elseif status == "dead" then
               if not ok then
                  error(rv, 0)
               else
                  -- the coroutine finished its execution
               end
            else
               ef("unhandled status returned from coroutine.status(): %s", status)
            end
         end
         runnables = runnables_next
      end

      resume_runnables()
   end

   function self.loop()
      running = true

      -- running phase
      while running do
         tick()
         if runnables:size() == 0
            and sleeping:size() == 0
            and n_waiting_threads == 0 then
               -- all threads exited without anyone calling
               -- sched.quit(), so we have to do it
               self.quit()
               -- schedule quit callbacks (if any)
               tick() -- also sets running to false
         end
      end

      -- shutdown phase
      while waiting['quit'] do
         -- quit callbacks are automatically removed (via sched.off)
         -- when they finish. when all quit handlers finish, there
         -- will be no more threads or callbacks waiting for 'quit',
         -- so we can shut down the scheduler.
         tick()
      end
   end

   function self.sched(fn, data)
      if fn then
         -- add fn to the list of runnable threads
         local t = coroutine.create(fn)
         runnables:push(Runnable(t, data))
      else
         -- enter the event loop, continue scheduling until there is
         -- work to do. when the event loop exits, cleanup and destroy
         -- this Scheduler instance.
         module_registry:invoke('init')
         self.loop()
         module_registry:invoke('done')
         poller:del(event_sub_fd, "r", event_sub_id)
         poller:close()
         nn.close(event_sub)
         scheduler_singleton = nil
         -- after this function returns, self (the current scheduler
         -- instance) will be garbage-collected
      end
   end

   function self.background(fn, data)
      local t = coroutine.create(fn)
      runnables:push(Runnable({t}, data))
   end

   self.yield = coroutine.yield
   self.wait = coroutine.yield

   function self.sleep(seconds)
      return self.wait(time.time() + seconds)
   end

   function self.emit(evtype, evdata)
      assert(evdata ~= nil, "evdata must be non-nil")
      event_queue:push({ evtype, evdata })
   end

   function self.quit(evdata)
      self.emit('quit', evdata or 0)
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
