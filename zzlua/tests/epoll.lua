local epoll = require('epoll')
local socket = require('socket')

local poller = epoll.create()
poller:close()
