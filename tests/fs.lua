local fs = require('fs')
local time = require('time')
local sched = require('sched')
local assert = require('assert')
local sf = string.format
local re = require('re')

local function oct(s)
   return tonumber(s, 8)
end

local function test_exists()
   assert(fs.exists('testdata/hello.txt'))
   assert(not fs.exists('non-existing-file'))
end

local function test_chmod()
   fs.chmod("testdata/hello.txt", oct("755"))
   assert.equals(fs.stat("testdata/hello.txt").perms, oct("755"))
   assert(fs.is_executable("testdata/hello.txt"))
   fs.chmod("testdata/hello.txt", oct("644"))
   assert(fs.stat("testdata/hello.txt").perms == oct("644"))
   assert(not fs.is_executable("testdata/hello.txt"))
end

local function test_readable_writable_executable()
   local hello_txt_perms = oct("644")
   fs.chmod("testdata/hello.txt", hello_txt_perms)

   assert(fs.is_readable("testdata/hello.txt"))
   assert(fs.is_writable("testdata/hello.txt"))
   assert(not fs.is_executable("testdata/hello.txt"))

   fs.chmod("testdata/hello.txt", 0)
   assert(not fs.is_readable("testdata/hello.txt"))
   assert(not fs.is_writable("testdata/hello.txt"))
   assert(not fs.is_executable("testdata/hello.txt"))

   fs.chmod("testdata/hello.txt", oct("400"))
   assert(fs.is_readable("testdata/hello.txt"))
   assert(not fs.is_writable("testdata/hello.txt"))
   assert(not fs.is_executable("testdata/hello.txt"))

   fs.chmod("testdata/hello.txt", oct("200"))
   assert(not fs.is_readable("testdata/hello.txt"))
   assert(fs.is_writable("testdata/hello.txt"))
   assert(not fs.is_executable("testdata/hello.txt"))

   fs.chmod("testdata/hello.txt", oct("100"))
   assert(not fs.is_readable("testdata/hello.txt"))
   assert(not fs.is_writable("testdata/hello.txt"))
   assert(fs.is_executable("testdata/hello.txt"))

   fs.chmod("testdata/hello.txt", hello_txt_perms)
end

local function test_stat()
   local s = fs.stat("testdata/hello.txt")
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
   assert.equals(fs.stat("non-existent"), nil, "fs.stat() result for non-existent file")

   -- "The field st_ctime is changed by writing or by setting inode
   -- information (i.e., owner, group, link count, mode, etc.)."
   fs.chmod("testdata/hello.txt", s.perms)
   local now = math.floor(time.time())
   assert(math.abs(now-s.ctime) <= 1.0, sf("time.time()=%d, s.ctime=%d, difference > 1.0 seconds", now, s.ctime))
end

local function test_type()
   assert(fs.type("testdata/hello.txt")=="reg")
   assert(fs.is_reg("testdata/hello.txt"))
   
   assert(fs.type("testdata")=="dir")
   assert(fs.is_dir("testdata"))
   
   assert(fs.type("testdata/hello.txt.symlink")=="lnk")
   assert(fs.is_lnk("testdata/hello.txt.symlink"))
   -- TODO: chr, blk, fifo, sock
   
   -- type of symlink pointing to non-existing file is "lnk"
   assert(fs.type("testdata/bad.symlink")=="lnk")
   assert(fs.is_lnk("testdata/bad.symlink"))

   -- but exists() returns false for such symlinks
   assert(fs.exists("testdata/hello.txt.symlink"))
   assert(not fs.exists("testdata/bad.symlink"))

   -- just like is_readable and is_writable
   assert(fs.is_readable("testdata/hello.txt.symlink"))
   assert(fs.is_writable("testdata/hello.txt.symlink"))
   assert(not fs.is_readable("testdata/bad.symlink"))
   assert(not fs.is_writable("testdata/bad.symlink"))
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
   local dir = fs.opendir("testdata")
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
   for f in fs.readdir("testdata") do
      table.insert(entries, f)
   end
   table.sort(entries)
   assert.equals(entries, expected_entries)
end

local function test_basename_dirname()
   assert.equals(fs.basename("testdata/hello.txt"), "hello.txt")
   assert.equals(fs.dirname("testdata/hello.txt"), "testdata")
end

local function test_join()
   assert.equals(fs.join(), nil)
   assert.equals(fs.join("abc"), "abc")
   assert.equals(fs.join("abc","def"), "abc/def")
   assert.equals(fs.join("abc",".", "def"), "abc/./def")
end

local function test()
   test_exists()
   test_chmod()
   test_readable_writable_executable()
   test_stat()
   test_type()
   test_readdir()
   test_basename_dirname()
   test_join()
end

-- sync
test()

-- async
sched(test)
sched()
