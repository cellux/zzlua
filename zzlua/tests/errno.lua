local ffi = require('ffi')
local errno = require('errno')
local file = require('file')
local assert = require('assert')

local res = ffi.C.open("/xxx/non-existent", ffi.C.O_RDONLY)
assert(res==-1)
assert(errno.errno()==ffi.C.ENOENT)
assert.equals(errno.strerror(), "No such file or directory")
