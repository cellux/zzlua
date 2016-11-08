local ffi = require('ffi')
local sched = require('sched')
local sdl = require('sdl2')
local fluid = require('fluidsynth')

local SAMPLE_RATE = 48000

local function main()
   local settings = fluid.Settings()
   settings:setnum("synth.gain", 4)
   settings:setint("synth.midi-channels", 256)
   settings:setnum("synth.sample-rate", SAMPLE_RATE)
   pf("synth.sample-rate=%s", settings:getnum("synth.sample-rate"))
   pf("synth.audio-channels=%s", settings:getint("synth.audio-channels"))
   pf("synth.midi-channels=%s", settings:getint("synth.midi-channels"))
   pf("synth.gain=%s", settings:getnum("synth.gain"))
   
   local synth = fluid.Synth(settings)
   
   local sf_path = "/usr/share/soundfonts/fluidr3/FluidR3GM.SF2"
   local sf_id = synth:sfload(sf_path, true)
   pf("successfully loaded %s, id=%d", sf_path, sf_id)
   
   pf("GetCurrentAudioDriver()=%s", sdl.GetCurrentAudioDriver())
   for i=1,sdl.GetNumAudioDevices() do
      pf("GetAudioDeviceName(%d)=%s", i, sdl.GetAudioDeviceName(i))
   end

   local dev = sdl.OpenAudioDevice {
      freq = SAMPLE_RATE,
      format = sdl.AUDIO_S16SYS,
      channels = 2,
      samples = 1024,
      callback = ffi.C.zz_fluidsynth_sdl_audio_callback,
      userdata = synth.synth
   }
   pf("SDL_OpenAudioDevice(): %d", dev.id)
   pf("  freq=%d", dev.freq)
   pf("  format=%d", dev.format)
   pf("  channels=%d", dev.channels)
   pf("  samples=%d", dev.samples)
   pf("  size=%d", dev.size)
   pf("unpausing audio device")
   dev:start()
   pf("noteon")
   synth:noteon(0, 64, 127)
   pf("sleep")
   sched.sleep(2)
   pf("pausing audio device")
   dev:stop()
   pf("closing audio device")
   dev:close()
   pf("cleanup fluidsynth")
   synth:delete()
   settings:delete()
end

sched(main)
sched()
