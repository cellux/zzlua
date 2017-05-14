local sdl = require('sdl2')
local util = require('util')

local function TextureAtlas(ui, opts)
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
         texture:update(src, dst_rect, src_rect)
         shelf_x = shelf_x + width
         if height > shelf_h then
            shelf_h = height
         end
         return dst_rect
      end
   end
   local function make_texture(size)
      local t = ui:Texture {
         format = self.format or "rgba",
         width = size,
         height = size,
      }
      t:clear(self.clear_color or Color(0,0,0,0))
      return t
   end
   self.texture = make_texture(self.size)
   local pack = ItemPacker(self.texture)
   function self:resize(new_size)
      local old_texture = self.texture
      local new_texture = make_texture(new_size)
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

return TextureAtlas
