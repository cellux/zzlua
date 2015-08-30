local sys = require('sys')
local ffi = require('ffi')
local assert = require('assert')
local file = require('file')
local socket = require('socket')
local sf = string.format

-- getpid

local ppid = sys.getpid()
assert(type(ppid) == "number")

-- fork, waitpid

local sp, sc = socket.socketpair(socket.PF_LOCAL, socket.SOCK_STREAM, 0)
local pid = sys.fork()
assert(type(pid)=="number")
if pid == 0 then
   -- child
   sp:close()
   sc:write(sf("%u\n", sys.getpid()))
   sc:close()
   assert(sys.getpid() ~= ppid)
   sys.exit()
else
   -- parent
   sc:close()
   assert(sys.getpid() == ppid)
   local child_pid = tonumber(sp:readline())
   sp:close()
   assert.equals(child_pid, pid)
   assert.equals(sys.waitpid(pid), pid)
end

-- the same, using some sugar

local pid, sp = sys.fork(function(sc)
      sc:write(sf("%u\n", sys.getpid()))
      sc:close()
      assert(sys.getpid() ~= ppid)
end)
assert(sys.getpid() == ppid)
local child_pid = tonumber(sp:readline())
sp:close()
assert.equals(child_pid, pid)
assert.equals(sys.waitpid(pid), pid)

-- system

local sp, sc = socket.socketpair(socket.PF_LOCAL, socket.SOCK_STREAM, 0)
local pid = sys.fork()
if pid == 0 then
   sp:close()
   -- redirect command's stdout to parent through socket
   assert.equals(ffi.C.dup2(sc.fd, 1), 1)
   sys.system("echo hello; echo world")
   sc:close()
   sys.exit()
else
   sc:close()
   assert.equals(sp:read(), "hello\nworld\n")
   sp:close()
   assert.equals(sys.waitpid(pid), pid)
end

-- execvp

local sp, sc = socket.socketpair(socket.PF_LOCAL, socket.SOCK_STREAM, 0)
local pid = sys.fork()
if pid == 0 then
   sp:close()
   -- redirect command's stdout to parent through socket
   assert.equals(ffi.C.dup2(sc.fd, 1), 1)
   sys.execvp("echo", {"echo", "hello", "world!"})
   -- doesn't return
else
   sc:close()
   assert.equals(sp:read(), "hello world!\n")
   sp:close()
   assert.equals(sys.waitpid(pid), pid)
end

-- waitpid, exit

local pid = sys.fork()
if pid == 0 then
   sys.exit(84)
else
   local rv, status = sys.waitpid(pid)
   assert.equals(rv, pid)
   -- status is a 16-bit word
   -- high byte is the exit status
   -- low byte is the cause of termination (0 = normal exit)
   assert.equals(status, 84*256,
                 sf("expected=%x, actual=%x", 84*256, status))
end

-- chdir, getcwd

local pid = sys.fork()
if pid == 0 then
   sys.chdir("/tmp")
   assert.equals(sys.getcwd(), "/tmp")
   sys.exit()
else
   sys.waitpid(pid)
end
