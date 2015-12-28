#!/usr/bin/env zzlua

local ffi = require('ffi')
local bit = require('bit')
local engine = require('engine')
local sched = require('sched')
local freetype = require('freetype')
local fs = require('fs')
local file = require('file')
local sdl = require('sdl2')
local iconv = require('iconv')
local time = require('time')
local util = require('util')
local round = util.round

local app = engine.DesktopApp {
   title = "render-text",
   --fullscreen_desktop = true,
}

local function TextureAtlas(size, renderer)
   local self = {
      size = size,
      items = {},
   }
   local function Packer(texture, size)
      local shelf_x = 0
      local shelf_y = 0
      local shelf_h = 0
      return function(src, src_rect, src_pitch)
         -- src: the pixels of the glyph which should be packed
         -- src_rect: location/size of the glyph in src
         -- src_pitch: pitch of the pixel data at src
         --
         -- src can be a texture or a pointer to pixel data
         -- if it's a texture, src_pitch is ignored
         local width, height = src_rect.w, src_rect.h
         if shelf_x + width > size then
            shelf_y = shelf_y + shelf_h
            shelf_x = 0
            shelf_h = 0
         end
         if shelf_x + width > size or shelf_y + height > size then
            return "full"
         end
         local dstrect = sdl.Rect(shelf_x, shelf_y, width, height)
         if type(src)=="table" then
            -- it's the texture of an existing atlas
            local old = renderer:GetRenderTarget()
            renderer:SetRenderTarget(texture)
            renderer:RenderCopy(src, src_rect, dstrect)
            renderer:SetRenderTarget(old)
         elseif type(src)=="cdata" then
            -- it's a pointer to the pixel data
            texture:UpdateTexture(dstrect, src, src_pitch)
         else
            ef("invalid source: %s", src)
         end
         shelf_x = shelf_x + width
         if height > shelf_h then
            shelf_h = height
         end
         return dstrect
      end
   end
   local function create_texture(size)
      local t = renderer:CreateTexture(sdl.SDL_PIXELFORMAT_RGBA8888,
                                       sdl.SDL_TEXTUREACCESS_TARGET,
                                       size, size)
      local old = renderer:GetRenderTarget()
      renderer:SetRenderTarget(t)
      renderer:SetRenderDrawColor(0,0,0,0)
      renderer:RenderClear()
      renderer:SetRenderTarget(old)
      t:SetTextureBlendMode(sdl.SDL_BLENDMODE_BLEND)
      return t
   end
   self.texture = create_texture(self.size)
   local pack = Packer(self.texture, self.size)
   function self:resize(new_size)
      pf("resizing atlas to %d", new_size)
      local new_texture = create_texture(new_size)
      local sorted_items = {}
      for k,v in pairs(self.items) do
         table.insert(sorted_items, { key=k, rect=v })
      end
      table.sort(sorted_items, function(a,b) return a.rect.h < b.rect.h end)
      local new_pack = Packer(new_texture, new_size)
      local new_items = {}
      for _,v in ipairs(sorted_items) do
         local dstrect = new_pack(self.texture, v.rect)
         assert(dstrect ~= "full")
         new_items[v.key] = dstrect
      end
      self.texture:DestroyTexture()
      self.texture = new_texture
      pack = new_pack
      self.items = new_items
      self.size = new_size
   end
   function self:add(key, rgba_pixels, width, height)
      --pf("add(%s,%d,%d)", key, width, height)
      assert(self.items[key] == nil)
      local rgba_pitch = width*4
      local srcrect = sdl.Rect(0, 0, width, height)
      local dstrect = pack(rgba_pixels, srcrect, rgba_pitch)
      if dstrect == "full" then
         self:resize(self.size*2)
         dstrect = pack(rgba_pixels, srcrect, rgba_pitch)
      end
      assert(dstrect ~= "full")
      self.items[key] = dstrect
      return dstrect
   end
   function self:get(key)
      return self.items[key]
   end
   function self:delete()
      if self.texture then
         self.texture:DestroyTexture()
         self.texture = nil
      end
   end
   return setmetatable(self, { __gc = self.delete })
end

local function Font(source, size, window, renderer)
   local self = {
      face = freetype.Face(source),
      size = nil, -- initialized below
      atlas = TextureAtlas(32, renderer),
   }
   function self:set_size(size)
      self.size = size -- measured in points
      self.face:Set_Char_Size(0, self.size*64, window:dpi())
      local metrics = self.face.face.size.metrics
      self.ascender = round(metrics.ascender / 64)
      self.descender = round(metrics.descender / 64)
      self.height = round(metrics.height / 64)
      self.max_advance = round(metrics.max_advance / 64)
   end
   self:set_size(size)
   local glyph_cache = {}
   function self:get_glyph(charcode)
      if not glyph_cache[charcode] then
         self.face:Load_Char(charcode)
         self.face:Render_Glyph(freetype.FT_RENDER_MODE_LCD)
         local g = self.face.face.glyph
         local gd = { -- glyph data
            bearing_x = g.bitmap_left,
            bearing_y = g.bitmap_top,
            advance_x = round(g.advance.x/64),
            advance_y = round(g.advance.y/64),
            width = 0,
            height = 0,
            texture = nil,
            srcrect = sdl.Rect(0,0,0,0),
         }
         local pixels = g.bitmap.buffer
         -- pixels can be nil when we draw a whitespace character
         if pixels ~= nil then
            local pitch = g.bitmap.pitch
            gd.width = g.bitmap.width/3
            gd.height = g.bitmap.rows
            local rgba_pitch = 4*gd.width
            local rgba_pixels = ffi.new("uint8_t[?]", rgba_pitch * gd.height)
            for y=0,gd.height-1 do
               for x=0,gd.width-1 do
                  local r = pixels[pitch*y+x*3+0]
                  local g = pixels[pitch*y+x*3+1]
                  local b = pixels[pitch*y+x*3+2]
                  local a = sdl.SDL_ALPHA_OPAQUE
                  if r == 0 and g == 0 and b == 0 then
                     a = sdl.SDL_ALPHA_TRANSPARENT
                  end
                  rgba_pixels[rgba_pitch*y+x*4+0] = a
                  rgba_pixels[rgba_pitch*y+x*4+1] = b
                  rgba_pixels[rgba_pitch*y+x*4+2] = g
                  rgba_pixels[rgba_pitch*y+x*4+3] = r
               end
            end
            gd.srcrect = self.atlas:add(charcode, rgba_pixels, gd.width, gd.height)
            gd.texture = self.atlas.texture
         end
         glyph_cache[charcode] = gd
      end
      local gd = glyph_cache[charcode]
      if gd.texture and gd.texture ~= self.atlas.texture then
         gd.texture = self.atlas.texture
         gd.srcrect = self.atlas:get(charcode)
      end
      return gd
   end
   function self:atlas_size()
      return self.atlas.size
   end
   function self:draw(dstrect)
      local srcrect = sdl.Rect(0, 0, self.atlas.size, self.atlas.size)
      renderer:RenderCopy(self.atlas.texture, srcrect, dstrect)
   end
   function self:delete()
      self.atlas:delete()
      glyph_cache = {}
      if self.face then
         face:Done_Face()
         self.face = nil
      end
   end
   return setmetatable(self, { __gc = self.delete })
end

function app:init()
   local script_path = arg[0]
   local script_contents = file.read(script_path)
   local script_dir = fs.dirname(script_path)
   local ttf_path = fs.join(script_dir, "DejaVuSerif.ttf")
   local font_size = 20 -- initial font size in points
   local font = Font(ttf_path, font_size, self.window, self.renderer)

   local text_top = 0
   local text_speed = 1
   sched(function()
         while true do
            text_top = text_top-text_speed
            sched.sleep(0.1)
         end
   end)
   sched.on('sdl.keydown', function(evdata)
      if evdata.key.keysym.sym == sdl.SDLK_SPACE then
         text_speed = 1-text_speed
      end
   end)

   local r = self.renderer

   local function lines(s)
      local index = 1
      local function next()
         local rv = nil
         if index <= #s then
            local lf_pos = s:find("\n", index, true)
            if lf_pos then
               rv = s:sub(index, lf_pos-1)
               index = lf_pos+1
            else
               rv = s:sub(index)
               index = #s+1
            end
         end
         return rv
      end
      return next
   end

   local function draw_char(font, charcode, ox, oy)
      local glyph_data = font:get_glyph(charcode)
      if glyph_data.width > 0 then
         local dstrect = sdl.Rect(ox+glyph_data.bearing_x,
                                  oy-glyph_data.bearing_y,
                                  glyph_data.width, glyph_data.height)
         r:RenderCopy(glyph_data.texture, glyph_data.srcrect, dstrect)
      end
      return glyph_data.advance_x
   end

   local function draw_string(font, s, x, y)
      local cp = iconv.utf8_codepoints(s)
      local ox = x
      local oy = y+font.ascender
      for i=1,#cp do
         local advance = draw_char(font, cp[i], ox, oy)
         ox = ox + advance
         if ox >= self.width then
            break
         end
      end
      return font.height
   end

   local avg_time = util.Accumulator()

   sched(function()
      while true do
         sched.sleep(1)
         pf("app:draw() takes %s seconds in average", avg_time.avg)
      end
   end)

   function app:draw()
      local t1 = time.time()
      r:SetRenderDrawColor(0,0,0,255)
      r:RenderClear()
      local top = text_top
      for line in lines(script_contents) do
         if top >= -font.height then
            draw_string(font, line, 0, top)
         end
         top = top + font.height
         if top >= self.height then
            break
         end
      end
      local atlas_size = font:atlas_size()
      font:draw(sdl.Rect(self.width-atlas_size,0,atlas_size,atlas_size))
      local t2 = time.time()
      local elapsed = t2 - t1
      avg_time:feed(elapsed)
   end

   function app:done()
      font:delete()
   end
end

app:run()
