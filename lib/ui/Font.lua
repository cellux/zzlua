local sdl = require('sdl2')
local freetype = require('freetype')
local round = require('util').round

local UI = {}

function UI.Font(ui, opts)
   opts = opts or {}
   local self = {
      face = freetype.Face(opts.source),
      size = nil, -- initialized below
      render_mode = opts.render_mode or freetype.FT_RENDER_MODE_LCD,
   }
   local atlas_texture_format
   if self.render_mode == freetype.FT_RENDER_MODE_LCD then
      atlas_texture_format = "rgb"
   elseif self.render_mode == freetype.FT_RENDER_MODE_NORMAL then
      atlas_texture_format = "a"
   else
      ef("invalid render_mode: %s", self.render_mode)
   end
   self.atlas = ui:TextureAtlas {
      size = 256,
      format = atlas_texture_format,
   }
   function self:set_size(size)
      self.size = size -- measured in points
      local hdpi, vdpi = ui:dpi()
      self.face:Set_Char_Size(0, self.size*64, hdpi, vdpi)
      local metrics = self.face.face.size.metrics
      self.ascender = round(metrics.ascender / 64)
      self.descender = round(metrics.descender / 64)
      self.height = round(metrics.height / 64)
      self.max_advance = round(metrics.max_advance / 64)
   end
   self:set_size(opts.size or 12)
   local glyph_cache = {}
   function self:load_glyph(charcode)
      if not glyph_cache[charcode] then
         self.face:Load_Char(charcode)
         self.face:Render_Glyph(self.render_mode)
         local g = self.face.face.glyph
         local gd = { -- glyph data
            bearing_x = g.bitmap_left,
            bearing_y = g.bitmap_top,
            advance_x = round(g.advance.x/64),
            advance_y = round(g.advance.y/64),
            width = 0,
            height = 0,
            texture = nil,
            src_rect = Rect(0,0,0,0),
         }
         local pixels = g.bitmap.buffer
         -- pixels can be nil when we draw a whitespace character
         if pixels ~= nil then
            local pitch = g.bitmap.pitch
            gd.height = g.bitmap.rows
            local pixbuf
            if self.render_mode == freetype.FT_RENDER_MODE_LCD then
               gd.width = g.bitmap.width/3
               pixbuf = ui:PixelBuffer("rgb", gd.width, gd.height)
               local writer = pixbuf:Writer { format = "rgb" }
               writer:write(pixels, pitch)
            elseif self.render_mode == freetype.FT_RENDER_MODE_NORMAL then
               gd.width = g.bitmap.width
               pixbuf = ui:PixelBuffer("a", gd.width, gd.height)
               local writer = pixbuf:Writer { format = "a" }
               writer:write(pixels, pitch)
            end
            gd.texture = self.atlas.texture
            gd.src_rect = self.atlas:add(charcode, pixbuf)
         end
         glyph_cache[charcode] = gd
      end
   end
   function self:get_glyph(charcode)
      self:load_glyph(charcode)
      local gd = glyph_cache[charcode]
      if gd.texture and gd.texture ~= self.atlas.texture then
         -- stale reference to a texture which has been deleted
         -- (most likely because the texture atlas has been resized)
         gd.texture = self.atlas.texture
         gd.src_rect = self.atlas:get(charcode)
      end
      return gd
   end
   function self:atlas_size()
      return self.atlas.size
   end
   function self:delete()
      if self.atlas then
         self.atlas:delete()
         glyph_cache = {}
         if self.face then
            face:delete()
            self.face = nil
         end
         self.atlas = nil
      end
   end
   return setmetatable(self, { __gc = self.delete })
end

return UI
