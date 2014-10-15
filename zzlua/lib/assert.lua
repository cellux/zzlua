local sf = string.format

local M = {}

local function assert_equals(x, y)
   assert(type(x) == type(y), sf("x.type=%s, y.type=%s", type(x), type(y)))
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
      assert(x==y, sf("%s != %s", x, y))
   end
end

M.equals = assert_equals

local M_mt = {}

function M_mt:__call(...)
   assert(...)
end

return setmetatable(M, M_mt)
