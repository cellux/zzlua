local bit = require('bit')
local sys = require('sys')
local jack = require('jack')
local sf = string.format
local sched = require('sched')
local assert = require('assert')
local time = require('time')

local client_name = sf("zzlua-jack-test-%d", sys.getpid())
local client, status = jack.client_open(client_name)
if not client then
   if bit.band(status, jack.JackServerFailed) ~= 0 then
      print("Jack server not running, skipping test")
      return
   else
      error("jack.open() failed")
   end
end

jack.port_register("midi_out", jack.DEFAULT_MIDI_TYPE, jack.JackPortIsOutput)
jack.port_register("midi_in", jack.DEFAULT_MIDI_TYPE, jack.JackPortIsInput)
jack.connect("midi_out", "midi_in")

local midi_data = nil
sched(function()
         jack.send_midi("midi_out", 0x90, 60, 100)
      end)
sched(function()
         midi_data = sched.yield('jack.midi')
      end)
sched()
assert.equals(midi_data, { 0x90, 60, 100 })

assert(jack.client_close()==0)
