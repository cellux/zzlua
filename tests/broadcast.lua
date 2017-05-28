local broadcast = require('broadcast')
local process = require('process')
local assert = require('assert')
local sched = require('sched')

-- the broadcast module provides an UDP-based message distribution
-- facility which lets you send messages to all zzlua processes
-- running anywhere on the local IP network, either on localhost
-- or on other machines.
--
-- to receive broadcast messages, you need exactly one *broadcast
-- listener* per host who distributes incoming broadcast messages to
-- local *broadcast subscribers* in a pubsub fashion.
--
-- the broadcast module registers itself as a scheduler module. when
-- you call sched(), the module checks whether a listener is already
-- running on the configured broadcast port (default: UDP 3532, may be
-- overridden by setting the ZZ_BROADCAST_PORT environment variable)
-- and if not, it starts one automatically.
--
-- when a message arrives, the listener publishes it on a nanomsg PUB
-- socket at tcp://localhost:3532. the port number is the same as that
-- used for receiving broadcast messages, just TCP instead of UDP.
-- zzlua processes which require the broadcast module automatically
-- poll this TCP port for messages and distribute them to all
-- registered callbacks.

-- requiring the broadcast module and starting the scheduler causes a
-- broadcast subscriber (and potentially a broadcast listener) to be
-- set up in the current process.

local pid, sp = process.fork(function(sc)
   sched(function()
      -- broadcast.setup() blocks until we have a working listener and
      -- subscriber
      broadcast.setup()
      sc:write("ready\n")
      assert.equals(sc:read(5), "stop\n")
   end)
   sched()
end)
sched(function()
   assert.equals(sp:read(6), "ready\n")
   sp:write("stop\n")
end)
sched()
sp:close()
process.waitpid(pid)

-- broadcasting events from process A
-- subscribing to them in process B

local pid, sp = process.fork(function(sc)
   local messages = {}
   sched(function()
      broadcast.setup()
      broadcast.on('broadcast-test', function(evdata)
         table.insert(messages, evdata)
      end)
      broadcast.on('broadcast-quit', function()
         sched.quit()
      end)
      sc:write("ready\n")
      sched.wait('quit')
   end)
   sched()
   assert.equals(messages, {'hello','world'})
end)

sched(function()
   assert.equals(sp:read(6), "ready\n")
   broadcast('broadcast-test', 'hello', '127.0.0.1')
   broadcast('broadcast-test', 'world', '127.0.0.1')
   broadcast('broadcast-quit', nil, '127.0.0.1')
end)
sched()

sp:close()
process.waitpid(pid)
