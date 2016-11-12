#!/usr/bin/env zzlua

local appfactory = require('appfactory')
local fs = require('fs')
local sched = require('sched')
local sdl = require('sdl2')
local gl = require('gl')
local util = require('util')
local time = require('time')

-- ensure that freetype registers with the scheduler to prevent:
-- 'FreeType functions can be used only after a call to freetype.init()'
require('freetype')

local app = appfactory.OpenGLApp {
   title = "chargrid",
   fullscreen_desktop = true,
   quit_on_escape = true,
}

local avg_time = util.Accumulator()

function app:init()
   local script_path = arg[0]
   local script_dir = fs.dirname(script_path)
   local ttf_path = fs.join(script_dir, "DroidSansMono.ttf")
   local font_size = 12 -- initial font size in points
   local ui = app.ui
   local font = ui:Font { source = ttf_path, size = font_size }
   local grid = ui:CharGrid { font = font, width = 80, height = 25 }
   grid:write(0,0, "Hello, world! www")
   grid:write(1,1, "Hello, Mikey!")
   grid:bg(1)
   grid:write(2,2, "ÁRVÍZTŰRŐ TÜKÖRFÚRÓGÉP")
   ui:add(grid)
   local packer = ui:HBox()
   packer:add(ui:Spacer())
   local palette_display = ui:TextureDisplay {
      texture = grid:palette():texture(),
   }
   packer:add(palette_display)
   local font_display = ui:TextureDisplay {
      texture = font.atlas.texture,
   }
   packer:add(font_display)
   ui:add(packer)
   font.atlas:on('texture-changed', function(new_texture)
      font_display.texture = new_texture
   end)
   local t1
   function app:draw()
      ui:calc_size()
      ui:layout()
      ui:clear()
      ui:draw()
      local t2 = time.time()
      if t1 then
         local elapsed = t2 - t1
         avg_time:feed(elapsed)
      end
      t1 = t2
   end
end

app:run()

pf("app:draw() took %s seconds in average", avg_time.avg)
