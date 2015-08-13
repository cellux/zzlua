local nn = require('nanomsg')
local ffi = require('ffi')
local time = require('time')
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
