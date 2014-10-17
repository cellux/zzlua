local adt = require('adt')
local time = require('time')
local nn = require('nanomsg')
local msgpack = require('msgpack')
local inspect = require('inspect')

local sf = string.format

local M = {}

-- a 'quit' event makes this false, causing the scheduler to exit
local running = true

-- runnable threads
local runnable = adt.List()

-- threads waiting for their time to come, ordered by wake-up time
local sleeping = adt.OrderedList(function(st) return st.time end)

-- threads waiting for an event to arrive
local waiting = {}
local waiting_count = 0

local function add_waiting(t)
   assert(waiting[t] == nil)
   waiting[t] = true
   waiting_count = waiting_count + 1
end

local function del_waiting(t)
   assert(waiting[t] == true)
   waiting[t] = nil
   waiting_count = waiting_count - 1
end

-- callbacks/threads listening to various events
local listeners = {}
local forever_listeners = {}

local function add_listener(msg_type, l, forever)
   if not listeners[msg_type] then
      listeners[msg_type] = {}
   end
   table.insert(listeners[msg_type], l)
   if forever then
      forever_listeners[l] = true
   end
end

add_listener('quit', function() running = false end, true)

local event_sub = nn.socket(nn.AF_SP, nn.SUB)
nn.setsockopt(event_sub, nn.SUB, nn.SUB_SUBSCRIBE, "")
nn.bind(event_sub, "inproc://events")

local sub_poll = nn.Poll()
sub_poll:add(event_sub, nn.POLLIN)

local event_pub = nn.socket(nn.AF_SP, nn.PUB)
nn.connect(event_pub, "inproc://events")

local function RunnableThread(t, data)
   return { t = t, data = data }
end

local function SleepingThread(t, time)
   return { t = t, time = time }
end

local loop -- declare for sched()

local function sched(fn, data)
   if fn then
      runnable:push(RunnableThread(coroutine.create(fn), data))
   else
      loop()
   end
end

-- tick: one iteration of the event loop
local function tick() 
   local now = time.time()

   -- wake up sleeping threads whose time has come
   while sleeping:size() > 0 and sleeping[0].time <= now do
      local st = sleeping:shift()
      runnable:push(RunnableThread(st.t, nil))
   end

   -- fetch next event from the queue
   local msg
   if runnable:size() == 0 then
      -- there are no runnable threads
      -- we recv using a timeout to avoid spinning
      local wait_until = now + 1 -- default timeout is 1 second
      if sleeping:size() > 0 then
         -- but may be shorter (or longer) if there are sleeping threads
         wait_until = sleeping[0].time
         -- if it's closer than 1 ms, we wait for 1 ms
         -- (that's the granularity of nn_poll)
         if wait_until - now < 0.001 then
            wait_until = now + 0.001
         end
      end
      local timeout = wait_until - now
      local nevents = sub_poll(timeout * 1000) -- ms
      if nevents > 0 then
         msg = nn.recv(event_sub)
      end
   else
      -- recv without timeout
      -- we get back nil if the queue was empty
      msg = nn.recv(event_sub, nn.DONTWAIT)
   end

   -- process event (if any)
   if msg then
      local unpacked = msgpack.unpack(msg)
      assert(type(unpacked) == "table")
      assert(#unpacked == 2)
      local msg_type = unpacked[1]
      local msg_data = unpacked[2]
      --print(sf("got event: %s: %s", msg_type, inspect(msg_data)))
      local ls = listeners[msg_type]
      if ls then
         for _,l in ipairs(ls) do
            if type(l) == "thread" then
               -- a sleeping thread, waiting for this event
               runnable:push(RunnableThread(l, msg_data))
               del_waiting(l)
            elseif type(l) == "function" then
               -- callback function
               sched(l, msg_data)
            else
               error(sf("unknown listener type: %s", l))
            end
         end
         -- we clear all listeners after they got notified, so they
         -- must re-register if they want to get notified again
         -- (except forever listeners)
         local remaining_listeners = {}
         for _,l in ipairs(listeners[msg_type]) do
            if forever_listeners[l] then
               table.insert(remaining_listeners, l)
            end
         end
         if #remaining_listeners > 0 then
            listeners[msg_type] = remaining_listeners
         else
            listeners[msg_type] = nil
         end
      end
   end

   -- resume next runnable coroutine
   if runnable:size() > 0 then
      local rt = runnable:shift()
      local t, data = rt.t, rt.data
      local ok, rv = coroutine.resume(t, data)
      local status = coroutine.status(t)
      if status == "suspended" then
         if type(rv) == "number" then
            -- the coroutine shall be resumed at the given time
            sleeping:push(SleepingThread(t, rv))
         elseif rv then
            -- rv is the event which shall wake up this coroutine
            add_listener(rv, t)
            add_waiting(t)
         else
            -- the coroutine shall be resumed in the next loop
            runnable:push(RunnableThread(t, nil))
         end
      elseif status == "dead" then
         if not ok then
            error(sf("coroutine died: %s", rv))
         else
            -- the coroutine finished its execution
         end
      else
         error(sf("unhandled status returned from coroutine.status(): %s", status))
      end
   end
end

loop = function()
   repeat
      tick()
   until not running or
      (runnable:size() == 0 and sleeping:size() == 0 and waiting_count == 0)
end

M.yield = coroutine.yield

function M.on(msg_type, callback)
   add_listener(msg_type, callback)
end

function M.on_forever(msg_type, callback)
   add_listener(msg_type, callback, true)
end

function M.emit(msg_type, msg_data)
   local msg = msgpack.pack({msg_type, msg_data})
   nn.send(event_pub, msg)
end

local M_mt = {}

function M_mt:__call(...)
   return sched(...)
end

return setmetatable(M, M_mt)
