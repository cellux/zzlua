-- tests for global definitions

local assert = require('assert')
local file = require('file')
local sys = require('sys')
local ffi = require('ffi')

-- sf

assert.equals(sf("Hello, %s", "world"), "Hello, world")

-- pf

local pid, sp = sys.fork(function(sc)
   ffi.C.dup2(sc.fd, 1)
   pf("Hello, %s\n", "world")
end)
assert.equals(sp:readline(), "Hello, world")
sp:close()
sys.waitpid(pid)

-- ef

local status, err = pcall(function() ef("Hello, %s", "world") end)
assert.equals(status, false)
assert.equals(err, "tests/zzlua.lua:24: Hello, world")
