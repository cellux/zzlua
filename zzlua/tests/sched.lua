local sched = require('sched')

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
