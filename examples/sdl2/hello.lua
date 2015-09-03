#!/usr/bin/env zzlua

local sdl = require('sdl2')
local sched = require('sched')

sched(function()
   pf("SDL version: %d.%d.%d", sdl.GetVersion())
   pf("Running on platform '%s'", sdl.GetPlatform())
   pf("Amount of RAM configured in the system: %d MB", sdl.GetSystemRAM())
   pf("Number of available CPU cores: %d", sdl.GetCPUCount())
end)

sched()
