#!/usr/bin/env zzlua

local engine = require('engine')
local sched = require('sched')
local fs = require('fs')
local file = require('file')
local sdl = require('sdl2')
local util = require('util')
local time = require('time')

-- ensure that freetype registers with the scheduler to prevent:
-- 'FreeType functions can be used only after a call to freetype.init()'
require('freetype')

local app = engine.DesktopApp {
   title = "render-text",
   fullscreen_desktop = true,
}

function app:init()
   local script_path = arg[0]
   local script_contents = file.read(script_path)
   local script_dir = fs.dirname(script_path)
   local ttf_path = fs.join(script_dir, "DejaVuSerif.ttf")
   local font_size = 20 -- initial font size in points
   local ui = app.ui
   local font = ui:Font { source = ttf_path, size = font_size }
   local text = ui:Text { text = script_contents, font = font }
   ui:add(text)
   local font_display = ui:TextureDisplay {
      texture = font.atlas.texture,
      right = 0, -- align to the right side of the ui area
   }
   ui:add(font_display)
   font.atlas:on('texture-changed', function(new_texture)
      font_display.texture = new_texture
   end)
   local text_speed = 1
   sched.on('sdl.keydown', function(evdata)
      if evdata.key.keysym.sym == sdl.SDLK_SPACE then
         text_speed = 1-text_speed
      end
   end)
   local avg_time = util.Accumulator()
   sched(function()
      while true do
         sched.sleep(1)
         pf("app:draw() takes %s seconds in average", avg_time.avg)
      end
   end)
   function app:draw()
      local t1 = time.time()
      text.top = text.top - text_speed
      ui:layout()
      ui:clear()
      ui:draw()
      local t2 = time.time()
      local elapsed = t2 - t1
      avg_time:feed(elapsed)
   end
end

app:run()
