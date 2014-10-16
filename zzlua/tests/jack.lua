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

local sample_rate
local buffer_size
local ports = {}
local connected_a, connected_b
local midi_data

sched.on_forever('jack.sample-rate', function(data)
                                        sample_rate = data
                                     end)
sched.on_forever('jack.buffer-size', function(data)
                                        buffer_size = data
                                     end)
sched.on_forever('jack.port-registration', function(data)
                                              local port, reg = unpack(data)
                                              assert(reg==1)
                                              table.insert(ports, port)
                                           end)
sched.on_forever('jack.port-connect', function(data)
                                         local a, b, connect = unpack(data)
                                         assert(connect==1)
                                         connected_a = a
                                         connected_b = b
                                      end)

sched(function()
         jack.port_register("midi_out",
                            jack.DEFAULT_MIDI_TYPE,
                            jack.JackPortIsOutput)
         jack.port_register("midi_in",
                            jack.DEFAULT_MIDI_TYPE,
                            jack.JackPortIsInput)
         jack.connect("midi_out", "midi_in")
         
         sched(function()
                  jack.send_midi("midi_out", 0x90, 60, 100)
               end)
         sched(function()
                  midi_data = sched.yield('jack.midi')
               end)
      end)
sched()

assert.type(sample_rate, 'number')
assert.type(buffer_size, 'number')
assert.equals(#ports, 2, "#ports")
assert.equals(connected_a, ports[1])
assert.equals(connected_b, ports[2])
assert.equals(midi_data, { 0x90, 60, 100 })

assert(jack.client_close()==0)
