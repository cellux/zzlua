#!/usr/bin/env zzlua

local appfactory = require('appfactory')
local sched = require('sched')
local fs = require('fs')
local file = require('file')
local sdl = require('sdl2')
local gl = require('gl')
local util = require('util')
local time = require('time')

-- ensure that freetype registers with the scheduler to prevent:
-- 'FreeType functions can be used only after a call to freetype.init()'
require('freetype')

local apptype = arg[1] or 'DesktopApp'

local appFactory = appfactory[apptype]
if not appFactory then
   ef("invalid apptype: %s", apptype)
end

local app = appFactory {
   title = "render-text",
   fullscreen_desktop = true,
   frame_time = 0,
   quit_on_escape = true,
}

local avg_time = util.Accumulator()

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
   local packer = ui:HBox()
   packer:add(ui:Spacer())
   local font_display = ui:TextureDisplay {
      texture = font.atlas.texture,
   }
   packer:add(font_display)
   ui:add(packer)
   font.atlas:on('texture-changed', function(new_texture)
      font_display.texture = new_texture
   end)
   local text_top = 0
   local text_speed = 60
   sched.on('sdl.keydown', function(evdata)
      if evdata.key.keysym.sym == sdl.SDLK_SPACE then
         text_speed = -text_speed
      end
   end)
   local t1
   function app:draw()
      ui:calc_size()
      ui:layout()
      text.rect.y = text_top
      ui:clear()
      ui:draw()
      local t2 = time.time()
      if t1 then
         local elapsed = t2 - t1
         avg_time:feed(elapsed)
      end
      t1 = t2
   end
   function app:update(delta)
      text_top = text_top - text_speed * delta
   end
end

app:run()

pf("app:draw() took %s seconds in average", avg_time.avg)
