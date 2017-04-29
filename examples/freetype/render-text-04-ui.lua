#!/usr/bin/env zzlua

local ui = require('ui')
local sched = require('sched')
local fs = require('fs')
local sdl = require('sdl2')

local function main()
   local ui = ui {
      title = "render-text",
      fullscreen_desktop = true,
      quit_on_escape = true,
   }

   local script_path = arg[0]
   local script_contents = fs.readfile(script_path)
   local script_dir = fs.dirname(script_path)
   local ttf_path = fs.join(script_dir, "DejaVuSerif.ttf")
   local font_size = 20 -- initial font size in points
   local font = ui:Font { source = ttf_path, size = font_size }
   local text = ui:Text { text = script_contents, font = font }
   ui:add(text)
   local text_top = 0
   local text_speed = 60
   local keymapper = ui:KeyMapper()
   keymapper:push {
      [sdl.SDLK_SPACE] = function()
         text_speed = -text_speed
      end,
   }
   local loop = ui:RenderLoop {
      frame_time = 0,
      measure = true,
   }
   local blitter = ui:TextureBlitter()
   local function draw_texture_atlas()
      local t = font.atlas.texture
      local dst_rect = Rect(ui.rect.w - t.width, 0, t.width, t.height)
      blitter:blit(font.atlas.texture, dst_rect)
   end
   function loop:draw()
      ui:layout()
      text.rect.y = text_top
      ui:clear()
      ui:draw()
      draw_texture_atlas()
   end
   function loop:update(dt)
      text_top = text_top - text_speed * dt
   end
   sched(loop)
   ui:show()
   sched.wait('quit')
end

sched(main)
sched()
