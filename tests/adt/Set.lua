local adt = require('adt')
local assert = require('assert')

local s = adt.Set()

assert(s:empty())
s:push(10)
s:push("abc")
local t = {1,2,3}
s:push(t)
assert(s:size()==3)
assert(not s:empty())
assert(s:contains(10))
assert(s:contains("abc"))
assert(s:contains(t))

s:remove("abc")
assert(s:size()==2)
assert(s:contains(10))
assert(not s:contains("abc"))
assert(s:contains(t))

s:clear()
assert(s:empty())
assert(not s:contains(10))
assert(not s:contains("abc"))
assert(not s:contains(t))

local s = adt.Set()
s:push(10)
s:push("abc")
s:push(t)

local items = {[10]=false, ["abc"]=false, [t]=false}
for i in s:iteritems() do
   items[i] = true
end
assert.equals(items, {[10]=true, ["abc"]=true, [t]=true})
