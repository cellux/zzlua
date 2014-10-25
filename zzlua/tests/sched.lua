local sched = require('sched')
local sf = string.format

-- coroutines

local coll = {}

local function make_co(value, steps, inc)
   return function()
      while steps > 0 do
         table.insert(coll, value)
         value = value + inc
         steps = steps - 1
         sched.yield()
      end
   end
end

sched(make_co(1,10,1))
sched(make_co(2,6,2))
sched(make_co(3,7,3))
sched()

local expected = { 
   1,  2,  3,
   2,  4,  6,
   3,  6,  9,
   4,  8, 12,
   5, 10, 15,
   6, 12, 18,
   7,     21,
   8,
   9,
   10,
}

assert(#expected == #coll)
for i=1,#expected do
   assert(coll[i] == expected[i])
end

-- a single data item passed to sched gets forwarded to the coroutine

local output
sched(function(x) output = x end, 42)
sched()
assert(output == 42)

-- emit

local output = nil
sched.on('my-signal',
         function(my_signal_data)
            output = my_signal_data
         end)
sched.emit('my-signal', 42.5)
sched()
assert(output == 42.5)

-- sleep waiting for event

local output = nil
sched(function()
         local wake_up_data = sched.yield('wake-up')
         assert(type(wake_up_data)=="table")
         assert(wake_up_data.value == 43)
         output = wake_up_data.value
      end)
-- we must make sure that the emit happens when the other thread is
-- already waiting for the event so we schedule this second
sched(function()
         sched.emit('wake-up', { value = 43 })
      end)
sched()
assert(output == 43, sf("output=%s", output))
