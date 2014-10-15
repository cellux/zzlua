local sf = string.format

local M = {}

local function assert_type(x, t, name_of_x)
   if name_of_x then
      assert(type(x)==t, sf("type(%s)==%s, expected %s", name_of_x, type(x), t))
   else
      assert(type(x)==t, sf("type(%s)==%s, expected %s", tostring(x), type(x), t))
   end
end

M.type = assert_type

local function assert_equals(x, y, name_of_x)
   assert(type(x) == type(y), sf("x.type (%s) != y.type (%s)", type(x), type(y)))
   if type(x)=="table" then
      assert(#x==#y)
      for i=1,#x do
         assert_equals(x[i], y[i])
      end
      for k,v in pairs(x) do
         assert_equals(x[k], y[k])
      end
      for k,v in pairs(y) do
         assert_equals(y[k], x[k])
      end
   else
      if name_of_x then
         assert(x==y, sf("%s is %s, expected %s", name_of_x, tostring(x), tostring(y)))
      else
         assert(x==y, sf("%s != %s", tostring(x), tostring(y)))
      end
   end
end

M.equals = assert_equals

local M_mt = {}

function M_mt:__call(...)
   assert(...)
end

return setmetatable(M, M_mt)
