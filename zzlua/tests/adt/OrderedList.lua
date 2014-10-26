local adt = require('adt')
local assert = require('assert')

local l = adt.OrderedList()
assert(l:empty())
l:push(50)
l:push(10)
l:push(30)
l:push(20)
assert(l:size() == 4)
assert(not l:empty())
assert(l[0] == 10, "l[0]="..l[0])
assert(l[1] == 20, "l[1]="..l[1])
assert(l[2] == 30, "l[2]="..l[2])
assert(l[3] == 50, "l[3]="..l[3])

local l = adt.OrderedList()
l:push("car")
l:push("apple")
l:push("yellowstone")
l:push("bridge")
assert(l[0]=="apple")
assert(l[1]=="bridge")
assert(l[2]=="car")
assert(l[3]=="yellowstone")

local l = adt.OrderedList(function(s) return s:len() end)
l:push("car")
l:push("apple")
l:push("yellowstone")
l:push("bridge")
assert(l[0]=="car")
assert(l[1]=="apple")
assert(l[2]=="bridge")
assert(l[3]=="yellowstone")

assert(l:shift()=="car")
assert(l:shift()=="apple")
assert(l:size()==2)
assert(l[0]=="bridge")
assert(l[1]=="yellowstone")

local l = adt.OrderedList()
l:push(20)
l:push(10)
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
