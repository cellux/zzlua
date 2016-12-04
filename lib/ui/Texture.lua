local gl = require('gl')

-- singleton framebuffer object used for rendering to textures
local texture_fbo = nil

local function gl_pixelformat(format)
   -- return format & type values expected by glTexImage2D
   if format == "rgba" then
      return gl.GL_RGBA, gl.GL_UNSIGNED_BYTE
   elseif format == "rgb" then
      return gl.GL_RGB, gl.GL_UNSIGNED_BYTE
   elseif format == "a" then
      return gl.GL_ALPHA, gl.GL_UNSIGNED_BYTE
   elseif format == "l" then
      return gl.GL_LUMINANCE, gl.GL_UNSIGNED_BYTE
   elseif format == "la" then
      return gl.GL_LUMINANCE_ALPHA, gl.GL_UNSIGNED_BYTE
   else
      ef("unsupported pixel format: %s", format)
   end
end

local function Texture(ui, opts)
   local texture = gl.Texture()
   local target = gl.GL_TEXTURE_2D
   gl.BindTexture(target, texture)
   gl.TexParameteri(target, gl.GL_TEXTURE_BASE_LEVEL, 0)
   gl.TexParameteri(target, gl.GL_TEXTURE_MAX_LEVEL, 0)
   gl.TexParameteri(target, gl.GL_TEXTURE_MIN_FILTER, opts.min_filter or gl.GL_LINEAR)
   gl.TexParameteri(target, gl.GL_TEXTURE_MAG_FILTER, opts.mag_filter or gl.GL_LINEAR)
   local level = 0
   local width = opts.width or 0
   local height = opts.height or 0
   local border = 0
   local format = opts.format or "rgba"
   local gl_format, gl_type = gl_pixelformat(format)
   local internalformat = gl_format
   -- allocate memory for the texture (uninitialized)
   gl.TexImage2D(target, level, internalformat,
                 width, height, border,
                 gl_format, gl_type, nil)
   local self = {
      is_texture = true,
      texture = texture,
      rect = Rect(0, 0, width, height),
      width = width,
      height = height,
      format = format,
      has_alpha = string.find(format, "a") and true or false,
   }
   function self:while_attached_to_fbo(fn)
      if not texture_fbo then
         texture_fbo = gl.Framebuffer()
      end
      local prev_binding = gl.GetInteger(gl.GL_FRAMEBUFFER_BINDING)
      texture_fbo:BindFramebuffer(gl.GL_FRAMEBUFFER)
      self.texture:BindTexture(gl.GL_TEXTURE_2D)
      gl.FramebufferTexture2D(gl.GL_FRAMEBUFFER,
                              gl.GL_COLOR_ATTACHMENT0,
                              gl.GL_TEXTURE_2D, self.texture, 0)
      fn()
      gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, prev_binding)
   end
   function self:clear(color)
      self:while_attached_to_fbo(function()
         if color then
            gl.ClearColor(color:floats())
         end
         gl.Clear(gl.GL_COLOR_BUFFER_BIT)
      end)
   end
   function self:update(src, dst_rect, src_rect)
      dst_rect = dst_rect or self.rect
      src_rect = src_rect or src.rect
      if src.is_texture then
         src:while_attached_to_fbo(function()
            gl.BindTexture(gl.GL_TEXTURE_2D, self.texture)
            local target = gl.GL_TEXTURE_2D
            local level = 0
            local xoffset = dst_rect.x
            local yoffset = self.rect.h - (dst_rect.y + dst_rect.h)
            local x = src_rect.x
            local y = src.rect.h - (src_rect.y + src_rect.h)
            local width = src_rect.w
            local height = src_rect.h
            gl.CopyTexSubImage2D(target, level,
                                 xoffset, yoffset,
                                 x, y, width, height)
         end)
      elseif src.is_pixelbuffer then
         assert(src.format==self.format)
         gl.BindTexture(gl.GL_TEXTURE_2D, self.texture)
         local target = gl.GL_TEXTURE_2D
         local level = 0
         local xoffset = dst_rect.x
         local yoffset = self.rect.h - (dst_rect.y + dst_rect.h)
         local width = src_rect.w
         local height = src_rect.h
         local gl_format, gl_type = gl_pixelformat(src.format)
         local data = src.buf
         gl.TexSubImage2D(target, level,
                          xoffset, yoffset,
                          width, height,
                          gl_format, gl_type, data)
      else
         ef("invalid update source: %s", src)
      end
   end
   function self:BindTexture(...)
      self.texture:BindTexture(...)
   end
   function self:delete()
      if self.texture then
         self.texture:delete()
         self.texture = nil
      end
   end
   return self
end

return Texture
