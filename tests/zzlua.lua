-- tests for global definitions

local assert = require('assert')
local fs = require('fs') -- for dup2
local process = require('process')
local ffi = require('ffi')
local sched = require('sched')

-- sf

assert.equals(sf("Hello, %s", "world"), "Hello, world")

-- pf

local pid, sp = process.fork(function(sc)
   ffi.C.dup2(sc.fd, 1)
   pf("Hello, %s\n", "world")
end)
assert.equals(sp:readline(), "Hello, world")
sp:close()
process.waitpid(pid)

-- ef

local status, err = pcall(function() ef("Hello, %s", "world") end)
assert.equals(status, false)
assert.type(err, "string")
assert.equals(err, "tests/zzlua.lua:25: Hello, world")

-- if we throw an error from a coroutine running inside the scheduler,
-- we'd like to get a valid backtrace which correctly shows where the
-- error happened

local function throwit()
   ef("Hello, %s", "world")
end
sched(function() throwit() end)
local status, err = pcall(sched)
assert.equals(status, false)
assert.type(err, "string")
-- we check only the first part of the error
--
-- the second part contains the global (non-coroutine-specific)
-- traceback appended by error()
local expected = [[tests/zzlua.lua:35: Hello, world
stack traceback:
	tests/zzlua.lua:35: in function 'throwit'
	tests/zzlua.lua:37: in function <tests/zzlua.lua:37>]]
assert.equals(err:sub(1,#expected), expected)
