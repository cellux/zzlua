local sched = require('sched')
local time = require('time')

local coll = {}

local function add(x)
   table.insert(coll, x)
end

sched(function()
         add(5)
         time.async_sleep(0.1)
         add(10)
         time.async_sleep(0.4)
         add(15)
         time.async_sleep(0.3)
         add(20)
         time.async_sleep(0.2)
         add(25)
      end)

sched(function()
         time.async_sleep(0.2)
         add(2)
         time.async_sleep(0.2)
         add(4)
         time.async_sleep(0.3)
         add(6)
         time.async_sleep(0.2)
         add(8)
      end)

sched()

local expected = { 5, 10, 2, 4, 15, 6, 20, 8, 25 }
assert(#coll == #expected, '#coll='..#coll)
for i=1,#coll do
   assert(coll[i] == expected[i])
end
