local stream = require('stream')
local sched = require('sched')
local assert = require('assert')

local function hexstr(bytes)
   local pieces = {}
   for i=1,#bytes do
      table.insert(pieces, sf("%02x", bytes:byte(i)))
   end
   return table.concat(pieces)
end

-- memory streams

local s = stream()

s:write("hello")
assert(not s:eof())
assert.equals(s:read(), "hello")
assert(s:eof())

s:write("hello\nworld\n")
assert.equals(s:readln(), "hello")
assert.equals(s:readln(), "world")
assert(s:eof())

s:write("hello\nworld\n")
assert.equals(s:read(0), "hello\nworld\n")
assert(s:eof())

s:write("hello\nworld\n")
assert.equals(s:read(2), "he")
assert.equals(s:read(5), "llo\nw")
assert.equals(s:read(0), "orld\n")
assert(s:eof())

do return end

-- files

local fs = require('fs')

local s = stream(fs.open("testdata/arborescence.jpg"))
assert(not s:eof())

-- read(n) reads n bytes
assert.equals(s:read(1), "\xff")
assert.equals(s:read(2), "\xd8\xff")
assert.equals(s:read(4), "\xe0\x00\x10\x4a")
assert.equals(s:read(8), "\x46\x49\x46\x00\x01\x01\x01\x00")

-- read() reads max stream.BUFFER_SIZE bytes
assert.equals(type(stream.BUFFER_SIZE), "number")
local data = s:read()
assert.equals(#data, stream.BUFFER_SIZE)
assert.equals(hexstr(digest.md5(data)), '97a61975b61aa68588eec3a7db2129d7')

-- pipes

local process = require('process')

-- network sockets

local net = require('net')
