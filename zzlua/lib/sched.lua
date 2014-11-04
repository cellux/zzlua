local adt = require('adt')
local time = require('time')
local nn = require('nanomsg')
local msgpack = require('msgpack')
local inspect = require('inspect')

local sf = string.format

local M = {}

local running = false

-- runnable threads
local runnable = adt.List()

-- threads waiting for their time to come, ordered by wake-up time
local sleeping = adt.OrderedList(function(st) return st.time end)

-- threads waiting for an event to arrive
-- key: thread, value: is it a background thread? (true/false)
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

-- event_sub: the socket we receive events from
local event_sub = nn.socket(nn.AF_SP, nn.SUB)
nn.setsockopt(event_sub, nn.SUB, nn.SUB_SUBSCRIBE, "")
nn.bind(event_sub, "inproc://events")

local sub_poll = nn.Poll()
sub_poll:add(event_sub, nn.POLLIN)

-- event_pub: the socket we send events to (sched.emit)
local event_pub = nn.socket(nn.AF_SP, nn.PUB)
nn.connect(event_pub, "inproc://events")

local function RunnableThread(t, data)
   return { t = t, data = data }
end

local function SleepingThread(t, time)
   return { t = t, time = time }
end

local loop -- for sched()

local function sched(fn, data)
   if fn then
      -- add fn to list of runnable threads
      runnable:push(RunnableThread(coroutine.create(fn), data))
   else
      -- start the event loop
      loop()
   end
end

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

   local function fetch_event()
      -- fetch next event from the queue
      local event
      if runnable:size() == 0 then
         -- there are no runnable threads
         -- we poll for events using a timeout to avoid tight-spinning
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
         local nevents = sub_poll(timeout * 1000) -- ms
         if nevents > 0 then
            event = nn.recv(event_sub)
         end
      else
         -- there are runnable threads waiting for execution
         -- we just peek into the event queue in a non-blocking way
         -- nn.recv() returns nil if the queue was empty
         event = nn.recv(event_sub, nn.DONTWAIT)
      end
      return event
   end

   local function process_event(event)
      local unpacked = msgpack.unpack(event)
      assert(type(unpacked) == "table")
      assert(#unpacked == 2, "event shall be a table of two elements, but it is "..inspect(unpacked))
      local evtype = unpacked[1]
      local evdata = unpacked[2]
      --print(sf("got event: evtype=%s, evdata=%s", evtype, inspect(evdata)))
      if evtype == 'quit' then
         -- after receiving quit, only those threads should be resumed
         -- which have registered for this event
         running = false
         runnable:clear()
      end
      local ls = listeners[evtype]
      if ls then
         for _,t in ipairs(ls) do
            runnable:push(RunnableThread(t, evdata))
            del_waiting(t)
         end
         -- we clear all listeners after they got woken up, so they
         -- must re-register if they want to get notified again (this
         -- happens automatically for listeners registered via
         -- sched.on())
         listeners[evtype] = nil
      end
   end

   -- don't try to process all pending events at once here
   -- (the current scheduling model doesn't support it)
   local event = fetch_event()
   if event then
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
               -- rv is the event which shall wake up this coroutine
               -- (might be a negative number -> used for async work)
               add_listener(rv, t)
               add_waiting(t, is_background)
            else
               -- the coroutine shall be resumed in the next loop
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

loop = function()
   running = true
   repeat
      tick()
   until not running or
      (runnable:size() == 0 and sleeping:size() == 0 and waiting_fg == 0)
end

M.yield = coroutine.yield
M.wait = coroutine.yield

function M.sleep(seconds)
   return M.wait(time.time() + seconds)
end

M.OFF = {}

function M.listen(evtype, t, is_background)
   assert(type(t)=='thread')
   add_listener(evtype, t)
   add_waiting(t, is_background)
end

function M.on(evtype, callback)
   local function w()
      while true do
         local evdata = M.wait(evtype, true)
         if callback(evdata) == M.OFF then
            break
         end
      end
   end
   -- run w() until it waits (yields) for the first time
   local t = coroutine.create(w)
   local status, evtype, is_background = coroutine.resume(t)
   -- register the waiting thread as a background listener
   -- (just as resume_runnable() would do in tick())
   M.listen(evtype, t, true)
   -- this - admittedly cumbersome - implementation of sched.on()
   -- ensures that the callback will be primed immediately after the
   -- sched.on() call
end

function M.emit(evtype, evdata)
   assert(evdata ~= nil, "evdata must be non-nil")
   local msg = msgpack.pack({evtype, evdata})
   nn.send(event_pub, msg)
end

function M.quit()
   M.emit('quit', 0)
   M.yield() -- without this, quit handlers may not get a chance to run
end

local M_mt = {}

function M_mt:__call(...)
   return sched(...)
end

return setmetatable(M, M_mt)
