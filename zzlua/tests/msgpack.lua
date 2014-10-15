local msgpack = require('msgpack')
local assert = require('assert')

local function test_pack_unpack(x)
   local packed = msgpack.pack(x)
   local unpacked = msgpack.unpack(packed)
   assert.equals(x, unpacked)
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
