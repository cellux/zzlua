local zmq = require('zmq')
local ffi = require('ffi')
local time = require('time')
local sf = string.format

local function isnumber(x)
   return type(x) == "number"
end

local major, minor, patch = zmq.version()
assert(isnumber(major))
assert(isnumber(minor))
assert(isnumber(patch))
-- print(sf("testing zmq version %d.%d.%d", major, minor, patch))

local ctx = zmq.Context()

local sub_sock = ctx:Socket(zmq.SUB)
sub_sock:setsockopt(zmq.SUBSCRIBE, "")
sub_sock:connect("inproc://messages")

local pub_sock = ctx:Socket(zmq.PUB)
pub_sock:bind("inproc://messages") -- bind the PUB, connect to SUB
pub_sock:send("hello")

local poll = zmq.Poll()
poll:add(sub_sock, 0, zmq.POLLIN) -- socket, fd, events
assert(#poll.items == 1)
local nevents = poll(-1) -- timeout in ms, -1=block
assert(nevents == 1, sf("poll() returned nevents=%d, expected 1", nevents))
assert(poll[0].revents == zmq.POLLIN)
local buf = ffi.new("uint8_t[?]", 64)
assert(ffi.sizeof(buf)==64)
local bytes_read = sub_sock:recv(buf, ffi.sizeof(buf))
assert(bytes_read == 5)
assert(ffi.string(buf, bytes_read)=="hello")

pub_sock:close()
sub_sock:close()
assert(ctx:term()==0)
