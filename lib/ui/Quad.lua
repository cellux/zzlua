local util = require('util')

local UI = {}

local function make_resolver(x)
   if type(x)=="function" then
      return function() return x() end
   else
      return function() return x end
   end
end

function UI.Quad(ui, opts)
   assert(opts.texture)
   local self = ui:Widget(opts)
   local blitter = ui:TextureBlitter()
   local resolve_texture = make_resolver(self.texture)
   function self:set_preferred_size()
      local t = resolve_texture()
      self.preferred_size = Size(t.width, t.height)
   end
   function self:draw()
      local t = resolve_texture()
      blitter:blit(t, self.rect, self.src_rect)
   end
   return self
end

return UI
