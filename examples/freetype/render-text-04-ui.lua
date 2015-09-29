#!/usr/bin/env zzlua

local engine = require('engine')
local sched = require('sched')
local fs = require('fs')
local file = require('file')
local sdl = require('sdl2')
local util = require('util')

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
   sched(function()
         while true do
            text.top = text.top - text_speed
            ui:layout()
            sched.sleep(0.1)
         end
   end)
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
   local timer = ui:Timer()
   ui:add(timer)
   ui:layout()
   function app:draw()
      timer:reset("draw.start")
      ui:clear()
      ui:draw()
      timer:mark("draw.end")
      avg_time:feed(timer:elapsed_until("draw.end"))
   end
end

app:run()
