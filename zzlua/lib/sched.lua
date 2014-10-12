local adt = require('adt')
local time = require('time')

local sf = string.format

local M = {}

local running = adt.List()
local sleeping = adt.OrderedList(function(st) return st.time end)

local function SleepingThread(time, t)
   return { time = time, t = t }
end

local function loop()
   while running:size() > 0 or sleeping:size() > 0 do
      local now = time.time()
      while sleeping:size() > 0 and sleeping[0].time <= now do
         local st = sleeping:shift()
         running:push(st.t)
      end
      if running:size() > 0 then
         local t = running:shift()
         local ok, rv = coroutine.resume(t)
         local status = coroutine.status(t)
         if status == "suspended" then
            if type(rv) == "number" then
               -- the coroutine shall be resumed at the given time
               sleeping:push(SleepingThread(rv, t))
            else
               -- the coroutine shall be resumed in the next loop
               running:push(t)
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
end

local function sched(fn)
   if fn then
      running:push(coroutine.create(fn))
   else
      loop()
   end
end

M.yield = coroutine.yield

local M_mt = {
   __call = function(func, ...)
      return sched(...)
   end
}

return setmetatable(M, M_mt)
