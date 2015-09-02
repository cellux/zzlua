local nn = require('nanomsg')
local ffi = require('ffi')
local time = require('time')
local sched = require('sched')
local sys = require('sys')
local assert = require('assert')
local sf = string.format

local function isnumber(x)
   return type(x) == "number"
end

local sub_sock = nn.socket(nn.AF_SP, nn.SUB)
nn.setsockopt(sub_sock, nn.SUB, nn.SUB_SUBSCRIBE, "")
nn.bind(sub_sock, "inproc://messages")

local pub_sock = nn.socket(nn.AF_SP, nn.PUB)
nn.connect(pub_sock, "inproc://messages")
nn.send(pub_sock, "hello")

local poll = nn.Poll()
poll:add(sub_sock, nn.POLLIN) -- socket, events
assert(#poll.items == 1)
local nevents = poll(-1) -- timeout in ms, -1=block
assert(nevents == 1, sf("poll() returned nevents=%d, expected 1", nevents))
assert(poll[0].revents == nn.POLLIN)
local buf = nn.recv(sub_sock)
assert(buf=="hello")

nn.close(pub_sock)
nn.close(sub_sock)

-- tcp

local pub_sock = nn.socket(nn.AF_SP, nn.PUB)
nn.connect(pub_sock, "tcp://127.0.0.1:54321")

local sub_sock = nn.socket(nn.AF_SP, nn.SUB)
nn.setsockopt(sub_sock, nn.SUB, nn.SUB_SUBSCRIBE, "")
nn.bind(sub_sock, "tcp://127.0.0.1:54321")

-- after the connect and the bind, there is a time period while the
-- connection gets established. during this period, messages sent to
-- the pub socket are permanently lost.

nn.send(pub_sock, "hello")
assert(nn.recv(sub_sock, nn.DONTWAIT)==nil)

nn.close(sub_sock)
nn.close(pub_sock)

-- tcp + wait for the connection to be established

sched(function()
   local pub_sock = nn.socket(nn.AF_SP, nn.PUB)
   nn.connect(pub_sock, "tcp://127.0.0.1:54321")

   local sub_sock = nn.socket(nn.AF_SP, nn.SUB)
   nn.setsockopt(sub_sock, nn.SUB, nn.SUB_SUBSCRIBE, "")
   nn.bind(sub_sock, "tcp://127.0.0.1:54321")

   local setup_done = false

   sched(function()
      while not setup_done do
         nn.send(pub_sock, "ping")
         sched.sleep(0.1)
      end
   end)

   -- wait for the first message to arrive
   local sub_sock_fd = nn.getsockopt(sub_sock, 0, nn.RCVFD)
   sched.poll(sub_sock_fd, "r")
   assert(nn.recv(sub_sock)=="ping")
   setup_done = true

   -- from now on, all messages will be delivered (but pub/sub is
   -- inherently unreliable, so in theory, there is no guarantee)
   local messages = {}
   sched(function()
      for i=1,10 do
         sched.poll(sub_sock_fd, "r")
         table.insert(messages, nn.recv(sub_sock))
      end
      assert(#messages==10)
      nn.close(sub_sock)
      nn.close(pub_sock)
   end)
   for i=1,10 do
      nn.send(pub_sock, sf("msg-%d", i))
   end
end)

sched()

-- tcp + wait between two processes

local pid, sp = sys.fork(function(sc)
   sched(function()
      local sub_sock = nn.socket(nn.AF_SP, nn.SUB)
      nn.setsockopt(sub_sock, nn.SUB, nn.SUB_SUBSCRIBE, "")
      nn.bind(sub_sock, "tcp://127.0.0.1:54321")
      -- wait for the first message to arrive
      local sub_sock_fd = nn.getsockopt(sub_sock, 0, nn.RCVFD)
      sched.poll(sub_sock_fd, "r")
      assert(nn.recv(sub_sock)=="ping")
      sc:write("got ping\n")
      -- from now on, all messages will be delivered (but pub/sub is
      -- inherently unreliable, so in theory, there is no guarantee)
      local messages = {}
      for i=1,10 do
         sched.poll(sub_sock_fd, "r")
         table.insert(messages, nn.recv(sub_sock))
      end
      assert(#messages==10)
      nn.close(sub_sock)
   end)
   sched()
end)

sched(function()
   local pub_sock = nn.socket(nn.AF_SP, nn.PUB)
   nn.connect(pub_sock, "tcp://127.0.0.1:54321")
   local setup_done = false
   sched(function()
      assert.equals(sp:readline(), "got ping")
      setup_done = true
   end)
   while not setup_done do
      nn.send(pub_sock, "ping")
      sched.sleep(0.1)
   end
   for i=1,10 do
      nn.send(pub_sock, sf("msg-%d", i))
   end
   nn.close(pub_sock)
end)
sched()
sp:close()
sys.waitpid(pid)
