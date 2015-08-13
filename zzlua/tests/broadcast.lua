local broadcast = require('broadcast')
local sys = require('sys')

-- the broadcast module provides an UDP-based message distribution
-- facility which lets you send messages to all zzlua processes
-- running anywhere on the local IP network.
--
-- to receive broadcast messages, you need exactly one broadcast
-- listener per host who distributes incoming broadcast messages to
-- local subscribers in a pubsub fashion.
--
-- the broadcast module registers itself as a scheduler module. when
-- you call sched(), the module checks whether a listener is already
-- running at the configured broadcast port (default: udp 3532, may be
-- overridden by setting the ZZ_BROADCAST_PORT environment variable)
-- and if not, it starts one automatically.
--
-- when a message arrives, the listener publishes it on a nanomsg PUB
-- socket at tcp://localhost:3532. (the port number is the same as
-- that used for receiving broadcast messages, just TCP instead of
-- UDP.) broadcast-enabled schedulers automatically subscribe to this
-- TCP port and convert incoming broadcast messages to standard
-- scheduler events.
