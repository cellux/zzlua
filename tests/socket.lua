local socket = require('socket')
local assert = require('assert')
local sys = require('sys')
local file = require('file')
local ffi = require('ffi')
local sf = string.format
local sched = require('sched')
local epoll = require('epoll')
local net = require('net')

-- open/close

assert.equals(socket.PF_LOCAL, 1)
assert.equals(socket.SOCK_DGRAM, 2)
local s = socket(socket.PF_LOCAL, socket.SOCK_DGRAM)
assert.type(s.fd, "number")
assert(s.fd > 0)
assert.equals(s:close(), 0)

-- shutdown
local s = socket(socket.PF_LOCAL, socket.SOCK_DGRAM)
assert.equals(s:shutdown(socket.SHUT_RD), 0)
assert.equals(s:shutdown(socket.SHUT_WR), 0)
assert.equals(s:close(), 0)

local s = socket(socket.PF_LOCAL, socket.SOCK_DGRAM)
assert.equals(s:shutdown(socket.SHUT_RDWR), 0)
assert.equals(s:close(), 0)

-- socketpair
local s1, s2 = socket.socketpair(socket.PF_LOCAL, socket.SOCK_STREAM)
assert(s1 ~= nil)
assert(s2 ~= nil)
s1:write("hello")
assert.equals(s2:read(5), "hello")
s2:write("world")
assert.equals(s1:read(5), "world")
s1:close()
s2:close()

-- IPC using socketpair
local sp, sc = socket.socketpair(socket.PF_LOCAL, socket.SOCK_STREAM)
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
local sp, sc = socket.socketpair(socket.PF_LOCAL, socket.SOCK_STREAM)
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

-- sockaddr

local socket_addr = socket.sockaddr(socket.AF_LOCAL, "/tmp/socket")
assert.equals(socket_addr.address, "/tmp/socket")

local socket_addr = socket.sockaddr(socket.AF_INET, "127.0.0.1", 54321)
assert.equals(socket_addr.address, "127.0.0.1")
assert.equals(socket_addr.port, 54321)

local socket_addr_1 = socket.sockaddr(socket.AF_INET, "127.0.0.1", 54321)
local socket_addr_2 = socket.sockaddr(socket.AF_INET, "127.0.0.1", 54321)
assert(socket_addr_1 == socket_addr_2)

-- listen, accept, connect (with local sockets)

local socket_path = file.mktemp("zzlua-test-socket")
local socket_addr = socket.sockaddr(socket.AF_LOCAL, socket_path)

local pid, sp = sys.fork(function(sc)
      assert.equals(sc:readline(), "server-ready")
      function send(msg)
         local client = socket(socket.PF_LOCAL, socket.SOCK_STREAM)
         client:connect(socket_addr)
         client:write(sf("%s\n", msg))
         assert.equals(client:readline(), msg)
         client:close()
      end
      send("hello, world!")
      send("quit")
end)

local server = socket(socket.PF_LOCAL, socket.SOCK_STREAM)
server.SO_REUSEADDR = true
server:bind(socket_addr)
server:listen()
sp:write("server-ready\n")
while true do
   local client = server:accept()
   local msg = client:readline()
   client:write(sf("%s\n", msg))
   client:close()
   if msg == "quit" then
      break
   end
end
server:close()
sp:close()
sys.waitpid(pid)

if file.exists(socket_path) then
   file.unlink(socket_path)
end

-- listen, accept, connect (with TCP sockets) + getsockname, getpeername

local server_host, server_port = "127.0.0.1", 54321
local server_addr = socket.sockaddr(socket.AF_INET, server_host, server_port)

local pid, sp = sys.fork(function(sc)
      assert.equals(sc:readline(), "server-ready")
      function send(msg)
         local client = socket(socket.PF_INET, socket.SOCK_STREAM)
         client:connect(server_addr)
         local client_addr = client:getsockname()
         assert.equals(client_addr.address, "127.0.0.1")
         assert.type(client_addr.port, "number")
         client:write(sf("%s\n", client_addr.address))
         client:write(sf("%d\n", client_addr.port))
         client:write(sf("%s\n", msg))
         assert.equals(client:readline(), msg)
         client:close()
      end
      send("hello, world!")
      send("quit")
end)

local server = socket(socket.PF_INET, socket.SOCK_STREAM)
server.SO_REUSEADDR = true
server:bind(server_addr)
server:listen()
sp:write("server-ready\n")
while true do
   local client = server:accept()
   local peer_addr = client:getpeername()
   local peer_address = client:readline()
   assert.equals(peer_address, "127.0.0.1")
   assert.equals(peer_address, peer_addr.address)
   local peer_port = tonumber(client:readline())
   assert.equals(peer_port, peer_addr.port)
   local msg = client:readline()
   client:write(sf("%s\n", msg))
   client:close()
   if msg == "quit" then
      break
   end
end
server:close()
sp:close()
sys.waitpid(pid)

-- sendto

local dst_addr = socket.sockaddr(socket.AF_INET, "127.0.0.1", 54321)
local s = socket(socket.PF_INET, socket.SOCK_DGRAM)
s:sendto("this message should be dropped", dst_addr)
s:close()

-- UDP sockets

local server_host, server_port = "127.0.0.1", 54321
local server_addr = socket.sockaddr(socket.AF_INET, server_host, server_port)

local pid, sp = sys.fork(function(sc)
      assert.equals(sc:readline(), "server-ready")
      function send(msg)
         local client = socket(socket.PF_INET, socket.SOCK_DGRAM)
         client:sendto(msg, server_addr)
         local reply, peer_addr = client:recvfrom()
         assert.equals(reply, msg)
         assert.equals(peer_addr.address, "127.0.0.1")
         assert.equals(peer_addr.port, 54321)
         client:close()
      end
      send("hello, world!")
      send("quit")
end)

local server = socket(socket.PF_INET, socket.SOCK_DGRAM)
server.SO_REUSEADDR = true
server:bind(server_addr)
--server:listen() -- not supported by SOCK_DGRAM style sockets
sp:write("server-ready\n")
while true do
   -- local client = server:accept() -- not supported
   local msg, peer_addr = server:recvfrom()
   assert.equals(peer_addr.address, "127.0.0.1")
   assert(type(peer_addr.port)=="number")
   server:sendto(msg, peer_addr)
   if msg == "quit" then
      break
   end
end
server:close()
sp:close()
sys.waitpid(pid)

-- a TCP server

local server_host, server_port = "127.0.0.1", 54321
local server_addr = socket.sockaddr(socket.AF_INET, server_host, server_port)

local n_req = 500 -- number of requests to send in one second

local requests = {}

-- generate a bunch of numerical expressions
--
-- the server will read the expression and reply with the evaluated
-- result

local function make_expr(sub_expr)
   if not sub_expr then
      return make_expr(tostring(math.random(10)))
   elseif #sub_expr > 20 then
      return sub_expr
   else
      local ops = "+-*" -- no / to avoid division by zero
      local i = math.random(#ops)
      local op = string.sub(ops,i,i)
      local lhs = sub_expr
      local rhs = tostring(math.random(10))
      if math.random() >= 0.5 then
         lhs, rhs = rhs, lhs
      end
      return make_expr(sf("(%s%s%s)", lhs, op, rhs))
   end
end

for i=1,n_req do
   table.insert(requests, make_expr())
end

local responses = {}

local function server()
   local socket = socket.socket(socket.PF_INET, socket.SOCK_STREAM)
   socket.SO_REUSEADDR = true
   socket:bind(server_addr)
   socket:listen()
   for i=1,n_req do
      local client = socket:accept()
      local peer_addr = client:getpeername()
      local expr = client:readline()
      local chunk = assert(loadstring("return "..expr))
      local value = tostring(chunk())
      client:write(sf("%s\n", value))
      client:close()
   end
   socket:close()
end

sched(server)

local function client(expr)
   -- distribute client requests evenly within one second
   sched.sleep(math.random())
   local client = socket.socket(socket.PF_INET, socket.SOCK_STREAM)
   client:connect(server_addr)
   client:write(sf("%s\n", expr))
   local response = client:readline()
   client:close()
   responses[expr] = response
end

for i=1,n_req do
   sched(client, requests[i])
end

sched()

for e,v in pairs(responses) do
   assert.equals(tostring(assert(loadstring("return "..e))()), v)
end

-- graceful way to shut down a network server:

local server_host, server_port = "127.0.0.1", 54321
local server_addr = socket.sockaddr(socket.AF_INET, server_host, server_port)

local tcp_server_gracefully_shut_down = false

local function tcp_server(s)
   s.SO_REUSEADDR = true
   s:bind(server_addr)
   s:listen()
   net.qpoll(s.fd, function()
      local client_fd = s:accept()
      -- handle connection
   end)
   s:close()
   tcp_server_gracefully_shut_down = true
end

local s = socket(socket.PF_INET, socket.SOCK_STREAM)
sched(tcp_server, s)
sched(function() sched.quit() end)
sched()
assert.equals(tcp_server_gracefully_shut_down, true)

-- connecting an UDP socket to the broadcast address and then calling
-- getsockname() on it returns the IP address of the interface which
-- would be used to send outgoing packets

local s = socket(socket.PF_INET, socket.SOCK_DGRAM)
s.SO_BROADCAST = true
local broadcast_addr = socket.sockaddr(socket.AF_INET, "255.255.255.255", 54321)
s:connect(broadcast_addr)
assert.type(s:getsockname().port, "number")
assert(string.match(s:getsockname().address, '^%d+%.%d+%.%d+%.%d+$'))
s:close()
