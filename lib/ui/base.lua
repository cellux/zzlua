local ffi = require('ffi')
local sdl = require('sdl2')
local freetype = require('freetype')
local time = require('time')
local util = require('util')
local round = util.round

local M = {}

local Widget = util.Class()

function Widget:create(opts)
   local self = opts or {}
   self.rect = sdl.Rect(0,0,0,0)
   self.left = self.left or 0
   self.top = self.top or 0
   return self
end

function Widget:size()
end

function Widget:draw()
end

function Widget:delete()
   -- destructor
end

local Container = util.Class(Widget)

function Container:create(opts)
   local self = Widget(opts)
   self.children = {}
   return self
end

function Container:add(widget)
   table.insert(self.children, widget)
end

function Container:layout()
   local cx, cy = self.rect.x, self.rect.y
   local cw, ch = self.rect.w, self.rect.h
   for _,widget in ipairs(self.children) do
      widget.rect.x = cx
      if widget.left then
         widget.rect.x = widget.rect.x + widget.left
      end
      widget.rect.y = cy
      if widget.top then
         widget.rect.y = widget.rect.y + widget.top
      end
      local w,h = widget:size()
      widget.rect.w = w or cw
      widget.rect.h = h or ch
      if widget.right then
         -- right overrides left
         widget.rect.x = self.rect.x + cw - widget.right - widget.rect.w
      end
      if widget.bottom then
         -- bottom overrides top
         widget.rect.y = self.rect.y + ch - widget.bottom - widget.rect.h
      end
   end
end

function Container:draw()
   for _,widget in ipairs(self.children) do
      widget:draw()
   end
end

function Container:delete()
   for _,widget in ipairs(self.children) do
      widget:delete()
   end
   self.children = {}
end

local UI = util.Class(Container)

function UI:create()
   return Container()
end

function UI:dpi()
   local hdpi = 72
   local vdpi = 72
   return hdpi, vdpi -- to be implemented in descendants
end

function UI:clear()
   -- to be implemented
end

function UI.Widget(ui, opts)
   return Widget(opts)
end

function UI.Container(ui, opts)
   return Container(opts)
end

function UI.TextureAtlas(ui, size)
   local self = util.EventEmitter {
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
            -- current shelf is full, open a new one
            shelf_y = shelf_y + shelf_h
            shelf_x = 0
            shelf_h = 0
         end
         if shelf_x + width > size or shelf_y + height > size then
            return "full"
         end
         local dst_rect = sdl.Rect(shelf_x, shelf_y, width, height)
         texture:update(dst_rect, src, src_rect, src_pitch)
         shelf_x = shelf_x + width
         if height > shelf_h then
            shelf_h = height
         end
         return dst_rect
      end
   end
   local function create_texture(size)
      local t = ui:Texture {
         format = sdl.SDL_PIXELFORMAT_RGBA8888,
         access = sdl.SDL_TEXTUREACCESS_TARGET,
         width = size,
         height = size,
      }
      t:clear(0,0,0,0)
      t:blendmode(sdl.SDL_BLENDMODE_BLEND)
      return t
   end
   self.texture = create_texture(self.size)
   local pack = Packer(self.texture, self.size)
   function self:resize(new_size)
      local new_texture = create_texture(new_size)
      local sorted_items = {}
      for k,v in pairs(self.items) do
         table.insert(sorted_items, { key=k, rect=v })
      end
      table.sort(sorted_items, function(a,b) return a.rect.h < b.rect.h end)
      local new_pack = Packer(new_texture, new_size)
      local new_items = {}
      for _,v in ipairs(sorted_items) do
         local dst_rect = new_pack(self.texture, v.rect)
         assert(dst_rect ~= "full")
         new_items[v.key] = dst_rect
      end
      self.texture:delete()
      self.texture = new_texture
      pack = new_pack
      self.items = new_items
      self.size = new_size
      self:emit('texture-changed', self.texture)
   end
   function self:add(key, rgba_pixels, width, height)
      --pf("add(%s,%d,%d)", key, width, height)
      assert(self.items[key] == nil)
      local rgba_pitch = width*4
      local src_rect = sdl.Rect(0, 0, width, height)
      local dst_rect = pack(rgba_pixels, src_rect, rgba_pitch)
      if dst_rect == "full" then
         self:resize(self.size*2)
         dst_rect = pack(rgba_pixels, src_rect, rgba_pitch)
      end
      assert(dst_rect ~= "full")
      self.items[key] = dst_rect
      return dst_rect
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

function UI.Font(ui, opts)
   opts = opts or {}
   opts.size = opts.size or 12 -- in points
   local self = {
      face = freetype.Face(opts.source),
      size = nil, -- initialized below
      atlas = ui:TextureAtlas(32),
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
   self:set_size(opts.size)
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
            src_rect = sdl.Rect(0,0,0,0),
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
            gd.src_rect = self.atlas:add(charcode, rgba_pixels, gd.width, gd.height)
            gd.texture = self.atlas.texture
         end
         glyph_cache[charcode] = gd
      end
      local gd = glyph_cache[charcode]
      if gd.texture and gd.texture ~= self.atlas.texture then
         -- stale reference to a texture which has been deleted
         gd.texture = self.atlas.texture
         gd.src_rect = self.atlas:get(charcode)
      end
      return gd
   end
   function self:atlas_size()
      return self.atlas.size
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

function UI:Timer(opts)
   local ui = self
   opts = opts or {}
   local self = ui:Widget(opts)
   local marks = {}
   local marks_by_label = {}
   local function create_mark(time, label, color)
      return {
         time = time,
         label = label,
         color = color,
      }
   end
   function self:reset(label, color)
      marks = {}
      marks_by_label = {}
      self:mark(label, color)
   end
   function self:mark(label, color)
      local now = time.time()
      local m = create_mark(now, label, color)
      table.insert(marks, m)
      marks_by_label[label] = m
   end
   function self:elapsed()
      return time.time() - marks[1].time
   end
   function self:elapsed_since(label)
      return time.time() - marks_by_label[label].time
   end
   function self:elapsed_until(label)
      return marks_by_label[label].time - marks[1].time
   end
   return self
end

M.UI = UI

local M_mt = {}

function M_mt:__call(...)
   return UI(...)
end

return setmetatable(M, M_mt)
