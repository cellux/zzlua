local ffi = require('ffi')
local sdl = require('sdl2')
local gl = require('gl')

local UI = {}

local Palette_mt = {}

function Palette_mt:__index(i)
   return self.palette:get_color(i)
end

function Palette_mt:__newindex(i, color)
   self.palette:set_color(i, color)
end

function UI.Palette(ui, ncolors)
   local self = {
      ncolors = ncolors,
      palette = sdl.Palette(ncolors),
      texture = ui:Texture {
         format = "rgb",
         min_filter = gl.GL_NEAREST,
         mag_filter = gl.GL_NEAREST,
         width = ncolors,
         height = 1,
      },
   }
   local colbuf = ffi.new("uint8_t[?]", ncolors*3)
   local pixbuf = ui:PixelBuffer("rgb", ncolors, 1, colbuf)
   function self:upload()
      for i=0,ncolors-1 do
         local color = self[i]
         colbuf[i*3+0] = color.r
         colbuf[i*3+1] = color.g
         colbuf[i*3+2] = color.b
      end
      self.texture:update(pixbuf)
   end
   function self:BindTexture(...)
      self.texture:BindTexture(...)
   end
   function self:delete()
      if self.palette then
         self.palette:delete()
         self.palette = nil
      end
      if self.texture then
         self.texture:delete()
         self.texture = nil
      end
   end
   return setmetatable(self, Palette_mt)
end

return UI
