local msgpack = require('msgpack')
local sf = string.format

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

local function test_pack_unpack(x)
   local packed = msgpack.pack(x)
   local unpacked = msgpack.unpack(packed)
   assert_equals(x, unpacked)
end

test_pack_unpack(nil)
test_pack_unpack(true)
test_pack_unpack(false)
test_pack_unpack(0)
test_pack_unpack(123)
test_pack_unpack(123.25)
test_pack_unpack("hello, world!")
test_pack_unpack({nil,true,false,0,123,123.25,"hello, world!"})
test_pack_unpack({[0]=true,[1]=false,[123]={x=123.25,y=-123.5},str="hello, world!"})
