local adt = require('adt')
local ffi = require('ffi')
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

local l = adt.List()
for i=1,10 do
   l:push(sf("item %d", i))
end
assert.equals(l:index("item 1"), 0)
assert.equals(l:index("item 5"), 4)
assert.equals(l:index("item 10"), 9)
assert.equals(l:index("item 20"), nil)

local l = adt.List()
for i=1,10 do
   l:push(sf("item %d", i))
end
l:remove_at(6)
assert.equals(l:size(), 9)
assert.equals(l[5], "item 6")
assert.equals(l[6], "item 8")
assert.equals(l[7], "item 9")
assert.equals(l[8], "item 10")
l:remove_at(8)
assert.equals(l:size(), 8)
assert.equals(l[7], "item 9")
assert.equals(l[8], nil)
l:remove_at(0)
assert.equals(l:size(), 7)
assert.equals(l[0], "item 2")
assert.equals(l[1], "item 3")
l:remove_at(10)
assert.equals(l:size(), 7)

local l = adt.List()
for i=1,10 do
   l:push(sf("item %d", i))
end
l:remove("item 5")
l:remove("item 1")
l:remove("item 10")
assert.equals(l:size(), 7)
assert.equals(l[0], "item 2")
assert.equals(l[1], "item 3")
assert.equals(l[2], "item 4")
assert.equals(l[3], "item 6")
assert.equals(l[4], "item 7")
assert.equals(l[5], "item 8")
assert.equals(l[6], "item 9")

-- List:remove() finds cdata objects

local l = adt.List()
local item1 = ffi.new("uint8_t[16]")
local item2 = ffi.new("uint8_t[16]")
local item3 = ffi.new("uint8_t[16]")
l:push(item1)
l:push(item2)
l:push(item3)
l:remove(item1)
l:remove(item2)
l:remove(item3)
assert(l:empty())
