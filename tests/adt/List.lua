local adt = require('adt')
local assert = require('assert')

local l = adt.List()
assert(l:empty())
l:push(10)
l:push(20)
l:push(30)
assert(l:size() == 3)
assert(not l:empty())
assert.equals(l[0], 10)
assert.equals(l[1], 20)
assert.equals(l[2], 30)

local l = adt.List()
l:push(10)
l:push(20)
l:push(30)

local keys = {}
for k in l:iterkeys() do
   table.insert(keys, k)
end
assert.equals(keys, {0, 1, 2})

local values = {}
for v in l:itervalues() do
   table.insert(values, v)
end
assert.equals(values, {10, 20, 30})

local items = {}
for k,v in l:iteritems() do
   items[k] = v
end
assert.equals(items, {[0]=10, [1]=20, [2]=30})
