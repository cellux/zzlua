#!/usr/bin/env zzlua

local ffi = require('ffi')
local appfactory = require('appfactory')
local sched = require('sched')
local sdl = require('sdl2')

local app = appfactory.DesktopApp {
   title = "renderer-test",
   quit_on_escape = true,
}

local function print_renderer_info(info)
   pf("  name: %s", ffi.string(info.name))
   pf("  SDL_RENDERER_SOFTWARE: %s",
      bit.band(info.flags, sdl.SDL_RENDERER_SOFTWARE) == 0 and "no" or "yes")
   pf("  SDL_RENDERER_ACCELERATED: %s",
      bit.band(info.flags, sdl.SDL_RENDERER_ACCELERATED) == 0 and "no" or "yes")
   pf("  SDL_RENDERER_PRESENTVSYNC: %s",
      bit.band(info.flags, sdl.SDL_RENDERER_PRESENTVSYNC) == 0 and "no" or "yes")
   pf("  SDL_RENDERER_TARGETTEXTURE: %s",
      bit.band(info.flags, sdl.SDL_RENDERER_TARGETTEXTURE) == 0 and "no" or "yes")
end

function app:init()
   local n = sdl.GetNumRenderDrivers()
   pf("number of available render drivers: %d", n)
   for i=1,n do
      pf("render driver #%d:", i)
      local info = sdl.GetRenderDriverInfo(i)
      print_renderer_info(info)
   end
   pf("selected renderer:")
   print_renderer_info(self.renderer:GetRendererInfo())
end

function app:draw()
   local r = self.renderer
   local black = sdl.Color(255,0,0,255)
   r:SetRenderDrawColor(black)
   r:RenderClear()
end

app:run()
