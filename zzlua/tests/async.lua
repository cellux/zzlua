local ffi = require('ffi')
local async = require('async')
local sched = require('sched')
local assert = require('assert')
local inspect = require('inspect')

local ASYNC_ECHO = async.register_worker(ffi.C.zz_async_echo_worker)

local delays = {1,2,3,4,5,6,7,8,9,10}
local payloads = {"string", 42, false, -42, true, 42.5, nil}
local expected_replies = {}
local actual_replies = {}

local function make_async_echo_requester(delay, payload)
   return function()
      -- zz_async_echo_worker takes a delay and returns the rest of
      -- its arguments packed into an array after delay seconds
      local reply = async.request(ASYNC_ECHO, delay, unpack(payload))
      table.insert(actual_replies, reply)
   end
end

for i=1,10 do
   local delay = table.remove(delays, math.random(#delays))
   local payload = {}
   for j=1,math.random(5) do
      table.insert(payload, payloads[math.random(#payloads)])
   end
   -- we scale down delay a bit so that the test doesn't take too long
   -- (which also makes the test fragile if the system has high load)
   sched(make_async_echo_requester(delay*0.02, payload))
   expected_replies[delay] = payload
end

sched()

assert.equals(actual_replies, expected_replies)
