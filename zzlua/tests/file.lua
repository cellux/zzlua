local file = require('file')
local time = require('time')
local assert = require('assert')
local sf = string.format

-- exists
assert(file.exists('testdata/hello.txt'))
assert(not file.exists('non-existing-file'))

-- chmod
local function oct(s) return tonumber(s, 8) end
file.chmod("testdata/hello.txt", oct("755"))
assert.equals(file.stat("testdata/hello.txt").perms, oct("755"))
assert(file.is_executable("testdata/hello.txt"))
file.chmod("testdata/hello.txt", oct("644"))
assert(file.stat("testdata/hello.txt").perms == oct("644"))
assert(not file.is_executable("testdata/hello.txt"))

-- stat
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

-- "The field st_ctime is changed by writing or by setting inode
-- information (i.e., owner, group, link count, mode, etc.)."
assert(math.abs(time.time()-s.ctime) < 1, sf("time.time()=%s, s.ctime=%s, difference > 1 seconds", time.time(), s.ctime))

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

-- reading directories
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
for i=1,3 do add_entry() end
assert(dir:read()==nil)
table.sort(entries)
assert.equals(entries, {'.', '..', 'hello.txt'})
assert.equals(dir:close(), 0)

local entries = {}
for f in file.readdir("testdata") do
   table.insert(entries, f)
end
table.sort(entries)
assert.equals(entries, {'.','..','hello.txt'})
