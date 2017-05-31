-- statements in this file are executed at startup

require('globals')

local process = require('process')
local sched = require('sched')
local epoll = require('epoll')
sched.poller_factory = epoll.poller_factory

require('app')
process.exit(0)
