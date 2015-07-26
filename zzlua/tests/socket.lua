local socket = require('socket')
local assert = require('assert')
local sys = require('sys')
local file = require('file')
local ffi = require('ffi')
local sf = string.format

-- open/close

assert.equals(socket.PF_LOCAL, 1)
assert.equals(socket.SOCK_DGRAM, 2)
local s = socket(socket.PF_LOCAL, socket.SOCK_DGRAM, 0)
assert.type(s.fd, "number")
assert(s.fd > 0)
assert.equals(s:close(), 0)

-- shutdown
local s = socket(socket.PF_LOCAL, socket.SOCK_DGRAM, 0)
assert.equals(s:shutdown(socket.SHUT_RD), 0)
assert.equals(s:shutdown(socket.SHUT_WR), 0)
assert.equals(s:close(), 0)

local s = socket(socket.PF_LOCAL, socket.SOCK_DGRAM, 0)
assert.equals(s:shutdown(socket.SHUT_RDWR), 0)
assert.equals(s:close(), 0)

-- socketpair
local s1, s2 = socket.socketpair(socket.PF_LOCAL, socket.SOCK_STREAM, 0)
assert(s1 ~= nil)
assert(s2 ~= nil)
s1:write("hello")
assert.equals(s2:read(5), "hello")
s2:write("world")
assert.equals(s1:read(5), "world")
s1:close()
s2:close()

-- IPC using socketpair
local sp, sc = socket.socketpair(socket.PF_LOCAL, socket.SOCK_STREAM, 0)
local pid = sys.fork()
if pid == 0 then
   -- child
   sp:close()
   assert.equals(sc:read(5), "hello")
   sc:write("world")
   assert.equals(sc:read(), "quit")
   sc:close()
   sys.exit()
else
   -- parent
   sc:close()
   sp:write("hello")
   assert.equals(sp:read(5), "world")
   sp:write("quit")
   sp:close()
   -- closing sp causes an EOF condition on sc in the child
   -- at this point, sc:read() returns and the child exits
   sys.waitpid(pid)
end

-- IPC using socketpair with line-oriented protocol
local sp, sc = socket.socketpair(socket.PF_LOCAL, socket.SOCK_STREAM, 0)
local pid = sys.fork()
if pid == 0 then
   -- child
   sp:close()
   assert.equals(sc:readline(), "hello")
   sc:write("world\n")
   assert.equals(sc:readline(), "quit")
   -- check that plain read() still works
   assert.equals(sc:read(10), "extra-data")
   sc:close()
   sys.exit()
else
   -- parent
   sc:close()
   sp:write("hello\n")
   -- sending quit immediately after hello shouldn't confuse the child
   sp:write("quit\n")
   assert.equals(sp:readline(), "world")
   sp:write("extra-data")
   sys.waitpid(pid)
   sp:close()
end

-- listen, accept, connect

local socket_path = file.mktemp("zzlua-test-socket")

local pid, sp = sys.fork(function(sc)
      assert.equals(sc:readline(), "server-ready")
      function send(msg)
         local client = socket(socket.PF_LOCAL, socket.SOCK_STREAM, 0)
         client:connect(socket_path)
         client:write(sf("%s\n", msg))
         assert.equals(client:readline(), msg)
         client:close()
      end
      send("hello, world!")
      send("quit")
end)

local server = socket(socket.PF_LOCAL, socket.SOCK_STREAM, 0)
server.SO_REUSEADDR = true
server:bind(socket_path)
server:listen()
sp:write("server-ready\n")
while true do
   local client, addr = server:accept()
   assert.equals(addr, "")
   local msg = client:readline()
   client:write(sf("%s\n", msg))
   client:close()
   if msg == "quit" then
      break
   end
end
sp:close()
sys.waitpid(pid)

if file.exists(socket_path) then
   file.unlink(socket_path)
end
