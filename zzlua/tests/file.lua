local file = require('file')

-- exists
assert(file.exists('testdata/hello.txt'))
assert(not file.exists('non-existing-file'))

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
