local file = require('file')
local fs = require('fs')
local time = require('time')
local sched = require('sched')
local assert = require('assert')
local sf = string.format
local re = require('re')

local function oct(s)
   return tonumber(s, 8)
end

local function test_read()
   -- read whole file at once
   local f = file('testdata/hello.txt')
   local contents = f:read()
   assert(contents=="hello, world!\n")
   f:close()

   -- read whole file at once, using helper func
   local contents = file.read('testdata/hello.txt')
   assert(contents=="hello, world!\n")

   -- read some bytes
   local f = file('testdata/hello.txt')
   local contents = f:read(5)
   assert(contents=="hello")
   f:close()

   -- if we want to read more bytes than the length of the file, we
   -- don't get an error
   local f = file('testdata/hello.txt')
   local contents = f:read(4096)
   assert(contents=="hello, world!\n")
   f:close()
end

local function test_seek()
   -- seek from start
   local f = file('testdata/hello.txt')
   assert(f:seek(5)==5)
   local contents = f:read()
   assert(contents==", world!\n")
   f:close()

   -- seek from end
   local f = file('testdata/hello.txt')
   assert(f:seek(-7)==7)
   local contents = f:read(5)
   assert(contents=="world")
   f:close()

   -- seek from current position
   local f = file('testdata/hello.txt')
   assert(f:seek(5)==5)
   assert(f:seek(2, true)==7)
   local contents = f:read(5)
   assert(contents=="world")
   f:close()
end

local function test_mkstemp()
   local f, path = file.mkstemp()
   assert(type(path)=="string")
   assert(fs.exists(path))
   assert(re.match("^/tmp/.+$", path))
   f:write("stuff\n")
   f:close()
   -- temp file should be still there
   assert(fs.exists(path))
   local f = file(path)
   assert.equals(f:read(), "stuff\n")
   f:close()
   fs.unlink(path)
   assert(not fs.exists(path))
end

local function test()
   test_read()
   test_seek()
   test_mkstemp()
end

-- sync
test()

-- async
sched(test)
sched()
