local ffi = require('ffi')
local sched = require('sched')
local nn = require('nanomsg')
local msgpack = require('msgpack')
local net = require('net')
local env = require('env')
local adt = require('adt')
local inspect = require('inspect')
local time = require('time')
local util = require('util')

local M = {}

local broadcast_port = tonumber(env.ZZ_BROADCAST_PORT or 3532)

local any_addr = net.sockaddr(net.AF_INET, "0.0.0.0", broadcast_port)
local broadcast_addr = net.sockaddr(net.AF_INET, "255.255.255.255", broadcast_port)
local local_addr = net.sockaddr(net.AF_INET, "127.0.0.1", broadcast_port)

local broadcast_socket = nil -- for broadcasting to network peers
local broadcast_socket_addr = nil -- sockaddr of outgoing socket

local event_address = sf("tcp://127.0.0.1:%u", broadcast_port)

local cbregistry = nil -- subscriber callbacks

local initialized = false

M.OFF = {}

function M.broadcast(evtype, evdata, dest_addr)
   M.wait_until_ready()
   evdata = evdata or 0
   dest_addr = dest_addr or broadcast_addr
   if type(dest_addr=='string') then
      dest_addr = net.sockaddr(net.AF_INET, dest_addr, broadcast_port)
   end
   local msg = msgpack.pack_array({evtype, evdata})
   broadcast_socket:sendto(msg, dest_addr)
end

function M.wait_until_ready()
   if not initialized then
      sched.wait('broadcast.initialized')
   end
end

local function listener()
   local s = net.socket(net.PF_INET, net.SOCK_DGRAM)
   local rv, err = pcall(s.bind, s, any_addr)
   if rv then
      -- bind successful
      --
      -- proxy incoming events to broadcast subscribers on this host
      local event_pub = nn.socket(nn.AF_SP, nn.PUB)
      nn.bind(event_pub, event_address)
      -- poll the listener socket for incoming events
      net.qpoll(s.fd, function()
         local msg, peer_addr = s:recvfrom()
         local sender_address = peer_addr.address
         local sender_port = peer_addr.port
         local unpacked = msgpack.unpack(msg)
         assert(type(unpacked) == "table")
         assert(#unpacked == 2, "broadcast message shall be a table of two elements, but it is "..inspect(unpacked))
         local evtype, evdata = unpack(unpacked)
         nn.send(event_pub, msgpack.pack_array({evtype, evdata, sender_address, sender_port}))
      end)
      nn.close(event_pub)
   end
   s:close()
end

local function subscriber()
   local event_sub = nn.socket(nn.AF_SP, nn.SUB)
   nn.setsockopt(event_sub, nn.SUB, nn.SUB_SUBSCRIBE, "")
   nn.connect(event_sub, event_address)
   local event_sub_fd = nn.getsockopt(event_sub, 0, nn.RCVFD)
   assert(event_sub_fd > 0)
   -- prime the subscriber
   local ping_attempts = 10
   local got_ping = false
   sched(function()
      while not got_ping do
         sched.poll(event_sub_fd, "r")
         local msg = nn.recv(event_sub)
         local unpacked = msgpack.unpack(msg)
         assert(type(unpacked) == "table")
         assert(#unpacked == 4, inspect(unpacked))
         local evtype, evdata, sender_address, sender_port = unpack(unpacked)
         if evtype == 'broadcast.ping' and sender_address == M.sender_address and sender_port == M.sender_port then
            got_ping = true
         end
      end
   end)
   while not got_ping and ping_attempts > 0 do
      local msg = msgpack.pack_array({'broadcast.ping', 0})
      broadcast_socket:sendto(msg, local_addr)
      ping_attempts = ping_attempts - 1
      sched.sleep(0.1)
   end
   if got_ping then
      initialized = true
      sched.emit('broadcast.initialized', 0)
   else
      error("cannot wire up broadcast subscriber to listener")
   end
   -- wait for events
   net.qpoll(event_sub_fd, function()
       local msg = nn.recv(event_sub)
       local unpacked = msgpack.unpack(msg)
       assert(type(unpacked) == "table")
       assert(#unpacked == 4, inspect(unpacked))
       local evtype, evdata, sender_address, sender_port = unpack(unpacked)
       cbregistry:emit(evtype, evdata, sender_address, sender_port)
   end)
   nn.close(event_sub)
end

local function BroadcastModule(sched)
   local function invoke_subscriber_callback(cb, evtype, evdata, sender_address, sender_port)
      local function wrapper()
         local rv = cb(evdata, sender_address, sender_port)
         if rv == M.OFF then
            M.off(evtype, cb)
         end
      end
      sched.sched(wrapper)
   end
   local self = {}
   function self.init()
      initialized = false
      broadcast_socket = net.socket(net.PF_INET, net.SOCK_DGRAM)
      broadcast_socket.SO_BROADCAST = true
      broadcast_socket:connect(broadcast_addr)
      broadcast_socket_addr = broadcast_socket:getsockname()
      M.sender_address = broadcast_socket_addr.address
      M.sender_port = broadcast_socket_addr.port
      cbregistry = util.EventEmitter({}, invoke_subscriber_callback)
      M.on = function(...) cbregistry:on(...) end
      M.off = function(...) cbregistry:off(...) end
      sched.background(listener)
      sched.background(subscriber)
   end
   function self.done()
      M.on = nil
      M.off = nil
      cbregistry = nil
      broadcast_socket:close()
      M.sender_port = nil
      M.sender_address = nil
      broadcast_socket_addr = nil
      broadcast_socket = nil
      initialized = false
   end
   return self
end

sched.register_module(BroadcastModule)

local M_mt = {}

function M_mt:__call(...)
   return self.broadcast(...)
end

return setmetatable(M, M_mt)
