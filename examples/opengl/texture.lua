#!/usr/bin/env zzlua

local appfactory = require('appfactory')
local sched = require('sched')
local fs = require('fs')
local file = require('file')
local sdl = require('sdl2')
local util = require('util')
local time = require('time')

local app = appfactory.OpenGLApp {
   gl_profile = 'core',
   gl_version = '3.0',
   title = "texture",
   fullscreen_desktop = true,
   exact_frame_timing = false,
}

function app:init()
   local ui = app.ui
   local texture = ui:Texture { width = 256, height = 256 }
   texture:clear(ui:Color(255,255,0,255))
   local texture_display = ui:TextureDisplay { texture = texture }
   ui:add(texture_display)
   local avg_time = util.Accumulator()
   sched(function()
      while true do
         sched.sleep(1)
         pf("app:draw() takes %s seconds in average", avg_time.avg)
      end
   end)
   local tt = 0
   function app:draw()
      local t1 = time.time()
      ui:calc_size()
      ui:layout()
      texture_display.rect.x = 256*math.sin(sched.now)
      texture_display.rect.y = 256*math.cos(sched.now)
      ui:clear(ui:Color(64,0,0))
      ui:draw()
      local t2 = time.time()
      local elapsed = t2 - t1
      avg_time:feed(elapsed)
   end
end

app:run()
