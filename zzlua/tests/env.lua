local env = require('env')
local assert = require('assert')
local sys = require('sys')
local ffi = require('ffi')
local file = require('file')
local socket = require('socket')

assert.type(env.PATH, "string")
assert(env.NONEXISTENT==nil)
env.ZZ_ENV_TEST=5
assert.type(env.ZZ_ENV_TEST, "string")
assert.equals(env.ZZ_ENV_TEST, "5")

local sp, sc = socket.socketpair(socket.PF_LOCAL, socket.SOCK_STREAM, 0)
local pid = sys.fork()
if pid == 0 then
   -- child
   sp:close()
   assert.equals(ffi.C.dup2(sc.fd, 1), 1)
   env.ZZ_ENV_TEST=6
   sys.execvp("sh", {"sh", "-c", 'echo "in the child, ZZ_ENV_TEST=$ZZ_ENV_TEST"'})
else
   -- parent
   sc:close()
   assert.equals(env.ZZ_ENV_TEST, "5")
   assert.equals(sp:read(), "in the child, ZZ_ENV_TEST=6\n")
   sp:close()
   sys.waitpid(pid)
end
