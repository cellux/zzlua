local ffi = require('ffi')
local sdl = require('sdl2')
local freetype = require('freetype')
local util = require('util')
local sys = require('sys')
local round = util.round

local Rect = require('dim').Rect
local Size = require('dim').Size

local M = {}

-- Object

local Object = util.Class()

function Object:create(opts)
   local self = opts or {}
   return self
end

function Object:delete()
   -- finalizer
end

-- Widget

local Widget = util.Class(Object)

function Widget:create(opts)
   local self = Object(opts)
   -- the post-layout location of the widget in screen cordinates
   -- this will be updated by self.parent:layout()
   self.rect = Rect(0,0,0,0)
   -- the preferred size of the widget, (0,0) means undefined
   self.size = Size(0,0)
   return self
end

function Widget:calc_size()
   -- update self.size here if you have a way to determine the
   -- widget's preferred size
end

function Widget:draw()
   -- draw the widget so that it fills self.rect
end

-- Container

local Container = util.Class(Widget)

function Container:create(opts)
   local self = Widget(opts)
   self.children = {}
   return self
end

function Container:add(widget)
   widget.parent = self
   table.insert(self.children, widget)
end

function Container:calc_size()
   self.size.w = 0
   self.size.h = 0
   for _,widget in ipairs(self.children) do
      widget:calc_size()
      if widget.size.w > self.size.w then
         self.size.w = widget.size.w
      end
      if widget.size.h > self.size.h then
         self.size.h = widget.size.h
      end
   end
end

function Container:layout()
   for _,widget in ipairs(self.children) do
      widget.rect.x = self.rect.x
      widget.rect.y = self.rect.y
      if widget.size.w > 0 then
         widget.rect.w = widget.size.w
      else
         widget.rect.w = self.rect.w
      end
      if widget.size.h > 0 then
         widget.rect.h = widget.size.h
      else
         widget.rect.h = self.rect.h
      end
      if widget.layout then
         widget:layout()
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

-- UI

local UI = util.Class(Container)

function UI:create()
   return Container()
end

function UI:dpi()
   -- to be specialized in descendants
   local hdpi = 72
   local vdpi = 72
   return hdpi, vdpi
end

function UI:clear(color)
   -- clear the screen with the current clear color
   -- if color is given, set it as the current clear color
end

function UI.Color(ui, r, g, b, a)
   return sdl.Color(r, g, b, a or 255)
end

function UI.Object(ui, opts)
   return Object(opts)
end

function UI.Widget(ui, opts)
   return Widget(opts)
end

function UI.Container(ui, opts)
   return Container(opts)
end

function UI.Spacer(ui)
   return ui:Widget()
end

function UI.Box(ui, opts)
   local self = ui:Container(opts)
   self.direction = self.direction or "h" -- horizontal by default
   function self:calc_size()
      self.size.w = 0
      self.size.h = 0
      if self.direction == "h" then
         for _,widget in ipairs(self.children) do
            widget:calc_size()
            if widget.size.h > self.size.h then
               self.size.h = widget.size.h
            end
         end
      elseif self.direction == "v" then
         for _,widget in ipairs(self.children) do
            widget:calc_size()
            if widget.size.w > self.size.w then
               self.size.w = widget.size.w
            end
         end
      else
         ef("invalid pack direction: %s", self.direction)
      end
   end
   function self:layout()
      local cx, cy = self.rect.x, self.rect.y
      local cw, ch = self.rect.w, self.rect.h
      local n_dyn_w = 0 -- number of widgets without explicit width
      local n_dyn_h = 0 -- number of widgets without explicit height
      -- remaining width/height for dynamically sized widgets
      local dyn_w,dyn_h = cw,ch
      -- we subtract all explicit widths/heights to get the remaining
      -- space which will be divided evenly among dynamic widgets
      for _,widget in ipairs(self.children) do
         if widget.size.w > 0 then
            dyn_w = dyn_w - widget.size.w
         else
            n_dyn_w = n_dyn_w + 1
         end
         if widget.size.h > 0 then
            dyn_h = dyn_h - widget.size.h
         else
            n_dyn_h = n_dyn_h + 1
         end
      end
      if dyn_w < 0 then
         dyn_w = 0
      end
      if dyn_h < 0 then
         dyn_h = 0
      end
      -- pack children
      local x,y = cx,cy
      for _,widget in ipairs(self.children) do
         widget.rect.x = x
         widget.rect.y = y
         if self.direction == "h" then
            if widget.size.w > 0 then
               widget.rect.w = widget.size.w
            else
               widget.rect.w = dyn_w / n_dyn_w
            end
            widget.rect.h = ch
            x = x + widget.rect.w
         elseif self.direction == "v" then
            widget.rect.w = cw
            if widget.size.h > 0 then
               widget.rect.h = widget.size.h
            else
               widget.rect.h = dyn_h / n_dyn_h
            end
            y = y + widget.rect.h
         else
            ef("invalid pack direction: %s", self.direction)
         end
      end
   end
   return self
end

function UI.HBox(ui, opts)
   local box = ui:Box(opts)
   box.direction = "h"
   return box
end

function UI.VBox(ui, opts)
   local box = ui:Box(opts)
   box.direction = "v"
   return box
end

function UI.TextureAtlas(ui, opts)
   local self = util.EventEmitter(opts)
   self.items = {}
   local function ItemPacker(texture)
      local shelf_x = 0
      local shelf_y = 0
      local shelf_h = 0
      return function(src, src_rect)
         -- src: the pixels of the item which should be packed
         -- src_rect: location/size of the item in src
         local width, height = src_rect.w, src_rect.h
         if shelf_x + width > texture.width then
            -- current shelf is full, open a new one
            shelf_y = shelf_y + shelf_h
            shelf_x = 0
            shelf_h = 0
         end
         if shelf_x + width > texture.width or shelf_y + height > texture.height then
            return "full"
         end
         local dst_rect = Rect(shelf_x, shelf_y, width, height)
         texture:update(dst_rect, src, src_rect)
         shelf_x = shelf_x + width
         if height > shelf_h then
            shelf_h = height
         end
         return dst_rect
      end
   end
   self.texture = self:make_texture(self.size)
   local pack = ItemPacker(self.texture)
   function self:resize(new_size)
      local old_texture = self.texture
      local new_texture = self:make_texture(new_size)
      -- copy items from old to new
      local sorted_items = {}
      for k,v in pairs(self.items) do
         table.insert(sorted_items, { key=k, rect=v })
      end
      -- items are copied in ascending order of their height
      -- to ensure that shelves are filled in an optimal way
      table.sort(sorted_items, function(a,b) return a.rect.h < b.rect.h end)
      local new_pack = ItemPacker(new_texture)
      local new_items = {}
      for _,item in ipairs(sorted_items) do
         local dst_rect = new_pack(old_texture, item.rect)
         assert(dst_rect ~= "full")
         new_items[item.key] = dst_rect
      end
      self.texture:delete()
      self.texture = new_texture
      pack = new_pack
      self.items = new_items
      self.size = new_size
      self:emit('texture-changed', self.texture)
   end
   function self:add(key, pixbuf)
      local width, height = pixbuf.width, pixbuf.height
      --pf("add(%s,%d,%d)", key, width, height)
      assert(self.items[key] == nil)
      local src_rect = Rect(0, 0, width, height)
      local dst_rect = pack(pixbuf, src_rect)
      if dst_rect == "full" then
         self:resize(self.size*2)
         dst_rect = pack(pixbuf, src_rect)
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
         self.texture:delete()
         self.texture = nil
      end
   end
   return setmetatable(self, { __gc = self.delete })
end

function UI.PixelBuffer(ui, format, width, height, buf, pitch_sign)
   local self = {
      is_pixelbuffer = true, -- very primitive (but fast) type id
      format = format,
      width = width,
      height = height,
      pitch_sign = pitch_sign or ui.pitch_sign,
   }
   self.bits_per_pixel = sdl.PixelFormatEnumToMasks(self.format)
   self.bytes_per_pixel = self.bits_per_pixel / 8
   self.pitch = self.width * self.bytes_per_pixel
   self.buf = buf or ffi.new("uint8_t[?]", self.pitch * self.height)
   function self:Writer(opts)
      local src_format = opts.format
      local dst_format = self.format
      local writer = {
         dst = self.buf,
         width = self.width,
         pitch = self.pitch,
      }
      if self.pitch_sign == -1 then
         -- rows are counted from bottom to top
         writer.dst = self.buf + (self.height-1) * self.pitch
         writer.pitch = -self.pitch
      end
      local code = ""
      local function codegen(line)
         code = code..line.."\n"
      end
      local function gen_blit(src_components, src_byte_order,
                              dst_components, dst_byte_order)
         codegen(sf("for i=1,%d do", writer.width))
         local dst_component_indices = {}
         for i=1,#dst_components do
            local c = dst_components:sub(i,i)
            dst_component_indices[c] = i-1
         end
         local function adjust_index(index, byte_count, byte_order)
            if byte_order and byte_order ~= "be" then
               return byte_count - index - 1
            else
               return index
            end
         end
         local function gen_copy(dst_index, src_index)
            codegen(sf("dst[%d]=src[%d]",
                       adjust_index(dst_index,
                                    #dst_components,
                                    dst_byte_order),
                       adjust_index(src_index,
                                    #src_components,
                                    src_byte_order)))
         end
         local function gen_write(dst_index, value)
            codegen(sf("dst[%d]=0x%x",
                       adjust_index(dst_index,
                                    #dst_components,
                                    dst_byte_order),
                       value))
         end
         local src_component_indices = {}
         for i=1,#src_components do
            local c = src_components:sub(i,i)
            src_component_indices[c] = i-1
            local dst_index = dst_component_indices[c]
            if not dst_index then
               ef("no index defined for component %s", c)
            end
            gen_copy(dst_index, i-1)
            dst_component_indices[c] = nil
         end
         -- the rest of destination components must be deduceable
         -- from src components
         for c,dst_index in pairs(dst_component_indices) do
            if c=="a" then
               assert(opts.key)
               codegen(sf("if src[%d]==0x%x and src[%d]==0x%x and src[%d]==0x%x then",
                          src_component_indices["r"],
                          bit.band(bit.rshift(opts.key,16),0xff),
                          src_component_indices["g"],
                          bit.band(bit.rshift(opts.key,8),0xff),
                          src_component_indices["b"],
                          bit.band(bit.rshift(opts.key,0),0xff)))
               codegen(sf("dst[%d]=0x00",
                          adjust_index(dst_index,
                                       #dst_components,
                                       dst_byte_order)))
               codegen "else"
               codegen(sf("dst[%d]=0xff",
                          adjust_index(dst_index,
                                       #dst_components,
                                       dst_byte_order)))
               codegen "end"
            else
               ef("unknown dst component: %s", c)
            end
         end
         codegen(sf("src=src+%d", #src_components))
         codegen(sf("dst=dst+%d", #dst_components))
         codegen "end"
      end
      codegen "return function(src, dst, width)"
      if dst_format==sdl.SDL_PIXELFORMAT_RGBA8888 then
         if src_format==sdl.SDL_PIXELFORMAT_RGB24 then
            gen_blit("rgb", nil, "rgba", ui.pixel_byte_order)
         else
            ef("unhandled src/dst format: %s/%s", src_format, dst_format)
         end
      else
         ef("unhandled dst_format: %s", dst_format)
      end
      codegen "end"
      --print(code)
      local _write_row = assert(loadstring(code))()
      function writer:write_row(src)
         _write_row(src, self.dst, self.width)
         self.dst = self.dst + self.pitch
      end
      return writer
   end
   return self
end

function UI.Font(ui, opts)
   opts = opts or {}
   opts.size = opts.size or 12 -- in points
   local self = {
      face = freetype.Face(opts.source),
      size = nil, -- initialized below
      atlas = ui:TextureAtlas { size = 32 },
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
            src_rect = Rect(0,0,0,0),
         }
         local pixels = g.bitmap.buffer
         -- pixels can be nil when we draw a whitespace character
         if pixels ~= nil then
            local pitch = g.bitmap.pitch
            gd.width = g.bitmap.width/3
            gd.height = g.bitmap.rows
            -- we convert from RGB888 to RGBA8888
            -- black pixels in source will be transparent
            local pixbuf = ui:PixelBuffer(sdl.SDL_PIXELFORMAT_RGBA8888,
                                          gd.width, gd.height)
            local writer = pixbuf:Writer {
               format = sdl.SDL_PIXELFORMAT_RGB24,
               key = 0x000000
            }
            for y=0,gd.height-1 do
               writer:write_row(pixels+pitch*y)
            end
            gd.texture = self.atlas.texture
            gd.src_rect = self.atlas:add(charcode, pixbuf)
         end
         glyph_cache[charcode] = gd
      end
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
            face:Done_Face()
            self.face = nil
         end
         self.atlas = nil
      end
   end
   return setmetatable(self, { __gc = self.delete })
end

M.UI = UI

local M_mt = {}

function M_mt:__call(...)
   return UI(...)
end

return setmetatable(M, M_mt)
