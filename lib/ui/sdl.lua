local base = require('ui.base')
local sdl = require('sdl2')
local dim = require('dim')
local iconv = require('iconv')
local util = require('util')
local ffi = require('ffi')

local M = {}

local UI = util.Class(base.UI)

function UI:create(window, renderer)
   local self = base.UI()
   self.window = window
   self.renderer = renderer
   self.pixel_byte_order = ffi.abi("le") and "le" or "be"
   self.pitch_sign = 1
   return self
end

function UI:dpi()
   return self.window:dpi()
end

function UI:layout()
   self.rect.w, self.rect.h = self.window:GetWindowSize()
   base.UI.layout(self)
end

function UI:clear(color)
   local r = self.renderer
   if color then
      r:SetRenderDrawColor(color:bytes())
   end
   r:RenderClear()
end

function UI.Texture(ui, opts)
   local r = ui.renderer
   return r:CreateTexture(opts.format or sdl.SDL_PIXELFORMAT_RGBA8888,
                          opts.access or sdl.SDL_TEXTUREACCESS_TARGET,
                          opts.width or 0, opts.height or 0)
end

function UI.TextureAtlas(ui, opts)
   opts.make_texture = function(self, size)
      local t = ui:Texture {
         format = self.format or sdl.SDL_PIXELFORMAT_RGBA8888,
         access = self.access or sdl.SDL_TEXTUREACCESS_TARGET,
         width = size,
         height = size,
      }
      t:clear(self.clear_color or ui:Color(0,0,0,0))
      t:blendmode(sdl.SDL_BLENDMODE_BLEND)
      return t
   end
   return base.UI.TextureAtlas(ui, opts)
end

function UI.TextureDisplay(ui, opts)
   assert(opts.texture)
   local self = ui:Widget(opts)
   function self:calc_size()
      self.size.w = self.texture.width
      self.size.h = self.texture.height
   end
   function self:draw()
      local src_rect = dim.Rect(0, 0, self.texture.width, self.texture.height)
      local r = ui.renderer
      r:RenderCopy(self.texture, src_rect, self.rect)
   end
   return self
end

function UI.Text(ui, opts)
   assert(opts.font)
   opts.text = opts.text or ""
   local self = ui:Widget(opts)

   local function draw_char(charcode, ox, oy)
      local glyph_data = self.font:get_glyph(charcode)
      if glyph_data.width > 0 then
         local dst_rect = dim.Rect(ox+glyph_data.bearing_x,
                                   oy-glyph_data.bearing_y,
                                   glyph_data.width, glyph_data.height)
         local r = ui.renderer
         r:RenderCopy(glyph_data.texture, glyph_data.src_rect, dst_rect)
      end
      return glyph_data.advance_x
   end

   local function draw_string(s, x, y)
      local cp = iconv.utf8_codepoints(s)
      local ox = x
      local oy = y+self.font.ascender
      local right = self.rect.x+self.rect.w
      for i=1,#cp do
         local advance = draw_char(cp[i], ox, oy)
         ox = ox + advance
         if ox >= right then
            break
         end
      end
      return self.font.height
   end

   function self:draw()
      local x,y = self.rect.x,self.rect.y
      local font_height = self.font.height
      for line in util.lines(self.text) do
         if y >= -font_height then
            draw_string(line, x, y)
         end
         y = y + font_height
         if y >= ui.rect.h then
            break
         end
      end
   end

   return self
end

M.UI = UI

local M_mt = {}

function M_mt:__call(...)
   return UI(...)
end

return setmetatable(M, M_mt)
