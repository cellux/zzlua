local file = require('file')
local time = require('time')
local sched = require('sched')
local assert = require('assert')
local sf = string.format

local function oct(s)
   return tonumber(s, 8)
end

local function test_exists()
   assert(file.exists('testdata/hello.txt'))
   assert(not file.exists('non-existing-file'))
end

local function test_chmod()
   file.chmod("testdata/hello.txt", oct("755"))
   assert.equals(file.stat("testdata/hello.txt").perms, oct("755"))
   assert(file.is_executable("testdata/hello.txt"))
   file.chmod("testdata/hello.txt", oct("644"))
   assert(file.stat("testdata/hello.txt").perms == oct("644"))
   assert(not file.is_executable("testdata/hello.txt"))
end

local function test_readable_writable_executable()
   local hello_txt_perms = oct("644")
   file.chmod("testdata/hello.txt", hello_txt_perms)

   assert(file.is_readable("testdata/hello.txt"))
   assert(file.is_writable("testdata/hello.txt"))
   assert(not file.is_executable("testdata/hello.txt"))

   file.chmod("testdata/hello.txt", 0)
   assert(not file.is_readable("testdata/hello.txt"))
   assert(not file.is_writable("testdata/hello.txt"))
   assert(not file.is_executable("testdata/hello.txt"))

   file.chmod("testdata/hello.txt", oct("400"))
   assert(file.is_readable("testdata/hello.txt"))
   assert(not file.is_writable("testdata/hello.txt"))
   assert(not file.is_executable("testdata/hello.txt"))

   file.chmod("testdata/hello.txt", oct("200"))
   assert(not file.is_readable("testdata/hello.txt"))
   assert(file.is_writable("testdata/hello.txt"))
   assert(not file.is_executable("testdata/hello.txt"))

   file.chmod("testdata/hello.txt", oct("100"))
   assert(not file.is_readable("testdata/hello.txt"))
   assert(not file.is_writable("testdata/hello.txt"))
   assert(file.is_executable("testdata/hello.txt"))

   file.chmod("testdata/hello.txt", hello_txt_perms)
end

local function test_stat()
   local s = file.stat("testdata/hello.txt")
   assert.type(s.dev, 'number')
   assert.type(s.ino, 'number')
   assert.type(s.mode, 'number')
   assert.type(s.perms, 'number')
   assert.type(s.type, 'number')
   assert.equals(s.mode, s.perms + s.type)
   assert.type(s.nlink, 'number')
   assert.type(s.uid, 'number')
   assert.type(s.gid, 'number')
   assert.type(s.rdev, 'number')
   assert.type(s.size, 'number')
   assert.equals(s.size, 14, "stat('testdata/hello.txt').size")
   assert.type(s.blksize, 'number')
   assert.type(s.blocks, 'number')
   assert.type(s.atime, 'number')
   assert.type(s.mtime, 'number')
   assert.type(s.ctime, 'number')

   -- stat for non-existent file returns nil
   assert.equals(file.stat("non-existent"), nil, "file.stat() result for non-existent file")

   -- "The field st_ctime is changed by writing or by setting inode
   -- information (i.e., owner, group, link count, mode, etc.)."
   file.chmod("testdata/hello.txt", s.perms)
   assert(math.abs(time.time()-s.ctime) < 1, sf("time.time()=%s, s.ctime=%s, difference > 1 seconds", time.time(), s.ctime))
end

local function test_type()
   assert(file.type("testdata/hello.txt")=="reg")
   assert(file.is_reg("testdata/hello.txt"))
   
   assert(file.type("testdata")=="dir")
   assert(file.is_dir("testdata"))
   
   assert(file.type("testdata/hello.txt.symlink")=="lnk")
   assert(file.is_lnk("testdata/hello.txt.symlink"))
   -- TODO: chr, blk, fifo, sock
   
   -- type of symlink pointing to non-existing file is "lnk"
   assert(file.type("testdata/bad.symlink")=="lnk")
   assert(file.is_lnk("testdata/bad.symlink"))

   -- but exists() returns false for such symlinks
   assert(file.exists("testdata/hello.txt.symlink"))
   assert(not file.exists("testdata/bad.symlink"))

   -- just like is_readable and is_writable
   assert(file.is_readable("testdata/hello.txt.symlink"))
   assert(file.is_writable("testdata/hello.txt.symlink"))
   assert(not file.is_readable("testdata/bad.symlink"))
   assert(not file.is_writable("testdata/bad.symlink"))
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

local function test_readdir()
   local expected_entries = {
      '.',
      '..',
      'hello.txt',
      'hello.txt.symlink',
      'bad.symlink',
   }
   table.sort(expected_entries)

   -- using dir:read()
   local entries = {}
   local dir = file.opendir("testdata")
   local function add_entry()
      local e = dir:read()
      if e then
         assert(type(e)=="string")
         table.insert(entries, e)
      end
      return e
   end
   for i=1,#expected_entries do add_entry() end
   assert(dir:read()==nil)
   table.sort(entries)
   assert.equals(entries, expected_entries)
   assert.equals(dir:close(), 0)

   -- using iterator
   local entries = {}
   for f in file.readdir("testdata") do
      table.insert(entries, f)
   end
   table.sort(entries)
   assert.equals(entries, expected_entries)
end

local function test()
   test_exists()
   test_chmod()
   test_readable_writable_executable()
   test_stat()
   test_type()
   test_read()
   test_seek()
   test_readdir()
end

-- sync
test()

-- async
sched(test)
sched()
