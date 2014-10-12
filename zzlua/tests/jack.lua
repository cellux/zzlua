local bit = require('bit')
local sys = require('sys')
local jack = require('jack')
local sf = string.format

local client_name = sf("zzlua-jack-test-%d", sys.getpid())
local client, status = jack.open(client_name)
if not client then
   if bit.band(status, jack.JackServerFailed) ~= 0 then
      print("Jack server not running, skipping test")
      return
   else
      error("jack.open() failed")
   end
end

assert(jack.activate()==0)
assert(jack.deactivate()==0)
assert(jack.close()==0)
