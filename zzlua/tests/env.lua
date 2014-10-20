local env = require('env')
local assert = require('assert')
local sys = require('sys')

assert.type(env.PATH, "string")
assert(env.NONEXISTENT==nil)
env.ZZ_ENV_TEST=5
assert.type(env.ZZ_ENV_TEST, "string")
assert.equals(env.ZZ_ENV_TEST, "5")

--[[ this works, but I commented it out until I have a proper
     mechanism for communicating with child processes so I can capture
     the printed value in the parent

local pid = sys.fork()
if pid == 0 then
   -- child
   env.ZZ_ENV_TEST=6
   sys.execvp("sh", {"sh", "-c", 'echo "in the child, ZZ_ENV_TEST=$ZZ_ENV_TEST"'}) -- prints 6
else
   -- parent
   print("in the parent, ZZ_ENV_TEST="..env.ZZ_ENV_TEST) -- prints 5
   sys.waitpid(pid)
end

]]--
