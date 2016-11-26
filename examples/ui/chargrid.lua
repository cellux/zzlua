#!/usr/bin/env zzlua

local ui = require('ui')
local fs = require('fs')
local sched = require('sched')

local function main()
   local ui = ui {
      title = "chargrid",
      fullscreen_desktop = true,
      quit_on_escape = true,
   }

   local script_path = arg[0]
   local script_dir = fs.dirname(script_path)
   local examples_dir = fs.dirname(script_dir)
   local ttf_path = fs.join(examples_dir, "freetype/DroidSansMono.ttf")
   if not fs.exists(ttf_path) then
      ef("missing ttf: %s", ttf_path)
   end
   local font_size = 12 -- initial font size in points
   local font = ui:Font { source = ttf_path, size = font_size }

   local grid = ui:CharGrid { font = font }

   local packer = ui:HBox()
   packer:add(grid)
   packer:add(ui:Spacer())
   local palette_display = ui:Quad {
      texture = grid.palette.texture,
   }
   packer:add(palette_display)
   local font_display = ui:Quad {
      texture = function() return font.atlas.texture end,
   }
   packer:add(font_display)
   ui:add(packer)
   ui:show()
   ui:layout()

   grid:write(0,0, "Hello, world! www")
   grid:write(1,1, "Hello, Mikey!")
   grid:bg(1)
   grid:write(2,2, "ÁRVÍZTŰRŐ TÜKÖRFÚRÓGÉP")

   local loop = ui:RenderLoop { measure = true }
   sched(loop)
   sched.wait('quit')
end

sched(main)
sched()
