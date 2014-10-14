local adt = require('adt')
local time = require('time')
local nn = require('nanomsg')
local msgpack = require('msgpack')

local sf = string.format

local M = {}

local running = adt.List()
local sleeping = adt.OrderedList(function(st) return st.time end)
local listeners = {}

local event_sub = nn.socket(nn.AF_SP, nn.SUB)
nn.setsockopt(event_sub, nn.SUB, nn.SUB_SUBSCRIBE, "")
nn.connect(event_sub, "inproc://events")

local sub_poll = nn.Poll()
sub_poll:add(event_sub, nn.POLLIN)

local event_pub = nn.socket(nn.AF_SP, nn.PUB)
nn.bind(event_pub, "inproc://events")

local function RunnableThread(t, data)
   return { t = t, data = data }
end

local function SleepingThread(t, time)
   return { t = t, time = time }
end

local function sched(fn, data)
   if fn then
      running:push(RunnableThread(coroutine.create(fn), data))
   else
      loop()
   end
end

local function loop()
   local now = time.time()

   -- wake up sleeping threads whose time has come
   while sleeping:size() > 0 and sleeping[0].time <= now do
      local st = sleeping:shift()
      running:push(RunnableThread(st.t, nil))
   end

   -- fetch next event from the queue
   local msg
   if running:size() == 0 then
      -- recv using timeout
      local wait_until = now + 1
      if sleeping:size() > 0 then
         wait_until = sleeping[0].time
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

   -- process event
   if msg then
      local unpacked = msgpack.unpack(msg)
      assert(type(unpacked) == "table")
      assert(#unpacked == 2)
      local msg_type = unpacked[1]
      local msg_data = unpacked[2]
      local ls = listeners[msg_type]
      if ls then
         for _,l in ipairs(ls) do
            if type(l) == "thread" then
               -- a sleeping thread, waiting for this event
               running:push(RunnableThread(l, msg_data))
            elseif type(l) == "function" then
               -- callback function
               sched(l, msg_data)
            else
               error(sf("unknown listener type: %s", l))
            end
         end
         listeners[msg_type] = nil
      end
   end

   -- resume next runnable coroutine
   if running:size() > 0 then
      local t, data = unpack(running:shift())
      local ok, rv = coroutine.resume(t, data)
      local status = coroutine.status(t)
      if status == "suspended" then
         if type(rv) == "number" then
            -- the coroutine shall be resumed at the given time
            sleeping:push(SleepingThread(t, rv))
         elseif rv then
            -- rv is the event which shall wake up this coroutine when
            -- it arrives
            local msg_type = rv
            if not listeners[msg_type] then
               listeners[msg_type] = {}
            end
            table.insert(listeners[msg_type], t)
            waiting[t] = true
         else
            -- the coroutine shall be resumed in the next loop
            running:push(RunnableThread(t, nil))
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
   if running:size() > 0 or sleeping:size() > 0 then
      loop()
   end
end

M.yield = coroutine.yield

function M.emit(msg_type, msg_data)
   local msg = msgpack.pack{msg_type, msg_data}
   nn.send(event_pub, msg)
end

local M_mt = {}

function M_mt:__call(...)
   return sched(...)
end

return setmetatable(M, M_mt)
