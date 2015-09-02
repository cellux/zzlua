local broadcast = require('broadcast')
local sys = require('sys')
local assert = require('assert')
local sched = require('sched')

-- the broadcast module provides an UDP-based message distribution
-- facility which lets you send messages to all zzlua processes
-- running anywhere on the local IP network, either on the same host
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

sched()

local pid, sp = sys.fork(function(sc)
   sched(function()
      sched.wait("broadcast.initialized")
      sc:write("ready\n")
      assert.equals(sc:readline(), "stop")
   end)
   sched()
end)
sched(function()
   assert.equals(sp:readline(), "ready")
   sp:write("stop\n")
end)
sched()
sp:close()
sys.waitpid(pid)

-- broadcasting events from process A
-- subscribing to them in process B

local pid, sp = sys.fork(function(sc)
   local messages = {}
   sched(function()
      broadcast.on('broadcast-test', function(evdata)
         table.insert(messages, evdata)
      end)
      broadcast.on('broadcast-quit', function()
         sched.emit('broadcast-quit', 0)
      end)
      sched.wait('broadcast.initialized')
      sc:write("ready\n")
      sched.wait('broadcast-quit')
   end)
   sched()
   assert.equals(messages, {'hello','world'})
end)

sched(function()
   assert.equals(sp:readline(), "ready")
   broadcast('broadcast-test', 'hello')
   broadcast('broadcast-test', 'world')
   broadcast('broadcast-quit')
end)
sched()

sp:close()
sys.waitpid(pid)
