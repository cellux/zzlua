local base = require('ui.base')
local gl = require('gl')
local sdl = require('sdl2')
local dim = require('dim')
local iconv = require('iconv')
local util = require('util')
local ffi = require('ffi')
local time = require('time')

local M = {}

local UI = util.Class(base.UI)

function UI:create(window)
   local self = base.UI()
   self.window = window
   self.pixel_byte_order = "be"
   self.pitch_sign = -1
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
   if color then
      gl.ClearColor(color:floats())
   end
   gl.Clear(gl.GL_COLOR_BUFFER_BIT)
end

-- singleton framebuffer object used for rendering to textures
local texture_fbo = nil

local function sdl2gl_pixelformat(format)
   -- return format & type values expected by glTexImage2D
   if format == sdl.SDL_PIXELFORMAT_RGBA8888 then
      return gl.GL_RGBA, gl.GL_UNSIGNED_BYTE
   else
      ef("unhandled SDL PixelFormat: %s", format)
   end
end

function UI.Texture(ui, opts)
   local texture = gl.Texture()
   local target = gl.GL_TEXTURE_2D
   gl.BindTexture(target, texture)
   gl.TexParameteri(target, gl.GL_TEXTURE_BASE_LEVEL, 0)
   gl.TexParameteri(target, gl.GL_TEXTURE_MAX_LEVEL, 0)
   gl.TexParameteri(target, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR)
   gl.TexParameteri(target, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR)
   local level = 0
   local width = opts.width or 0
   local height = opts.height or 0
   local border = 0
   local sdl_format = opts.format or sdl.SDL_PIXELFORMAT_RGBA8888
   local format, type = sdl2gl_pixelformat(sdl_format)
   local internalformat = format
   -- allocate memory for the texture (uninitialized)
   gl.TexImage2D(target, level, internalformat,
                 width, height, border, format, type, nil)
   local self = {
      is_texture = true,
      texture = texture,
      rect = dim.Rect(0, 0, width, height),
      width = width,
      height = height,
      format = sdl_format,
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
   function self:update(dst_rect, src, src_rect)
      dst_rect = dst_rect or self.rect
      if src.is_texture then
         src:while_attached_to_fbo(function()
            gl.BindTexture(gl.GL_TEXTURE_2D, self.texture)
            local target = gl.GL_TEXTURE_2D
            local level = 0
            local xoffset = dst_rect.x
            local yoffset = self.height - (dst_rect.y + dst_rect.h)
            local x = src_rect.x
            local y = src.height - (src_rect.y + src_rect.h)
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
         local yoffset = self.height - (dst_rect.y + dst_rect.h)
         local width = src_rect.w
         local height = src_rect.h
         local format, type = sdl2gl_pixelformat(src.format)
         local data = src.buf
         gl.TexSubImage2D(target, level,
                          xoffset, yoffset,
                          width, height,
                          format, type, data)
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

function UI.TextureAtlas(ui, opts)
   opts.make_texture = function(self, size)
      local t = ui:Texture {
         format = self.format or sdl.SDL_PIXELFORMAT_RGBA8888,
         width = size,
         height = size,
      }
      t:clear(self.clear_color or ui:Color(0,0,0,0))
      return t
   end
   return base.UI.TextureAtlas(ui, opts)
end

function UI.TextureDisplay(ui, opts)
   assert(opts.texture)
   local self = ui:Widget(opts)
   local rm = gl.ResourceManager()
   local vertex_shader = rm:Shader(gl.GL_VERTEX_SHADER)
   vertex_shader:ShaderSource [[
      #version 120
      attribute vec2 vposition;
      attribute vec2 vtexcoord;
      uniform mat3 vscale;
      uniform mat3 vtranslate;
      varying vec2 ftexcoord;
      void main() {
        ftexcoord = vtexcoord;
        gl_Position = vec4(vtranslate * vscale * vec3(vposition,1.0), 1.0);
      }
   ]]
   vertex_shader:CompileShader()
   local fragment_shader = rm:Shader(gl.GL_FRAGMENT_SHADER)
   fragment_shader:ShaderSource [[
      #version 120
      uniform sampler2D ftex;
      varying vec2 ftexcoord;
      void main() {
         gl_FragColor = texture2D(ftex, ftexcoord);
      }
   ]]
   fragment_shader:CompileShader()

   local shader_program = rm:Program()
   shader_program:AttachShader(vertex_shader)
   shader_program:AttachShader(fragment_shader)
   shader_program:LinkProgram()
   local loc = {
      vposition = shader_program:GetAttribLocation("vposition"),
      vtexcoord = shader_program:GetAttribLocation("vtexcoord"),
      vscale = shader_program:GetUniformLocation("vscale"),
      vtranslate = shader_program:GetUniformLocation("vtranslate"),
      ftex = shader_program:GetUniformLocation("ftex"),
   }
   local vscale = gl.FloatArray {
      1,0,0,
      0,1,0,
      0,0,1,
   }
   local vtranslate = gl.FloatArray {
      1,0,0,
      0,1,0,
      0,0,1,
   }
   local vertex_data = gl.FloatArray {
      -- x, y
      0, 0, -- bottom left
      0, 1, -- top left
      1, 0, -- bottom right
      1, 1, -- top right
   }
   -- we can use the same data for texture coordinates
   local vbo = rm:VBO(ffi.sizeof(vertex_data), vertex_data, gl.GL_STATIC_DRAW)
   function self:calc_size()
      self.size.w = self.texture.width
      self.size.h = self.texture.height
   end
   function self:draw()
      gl.UseProgram(shader_program)
      vscale[0*3+0] = (2.0/ui.rect.w) * self.rect.w
      vscale[1*3+1] = (2.0/ui.rect.h) * self.rect.h
      gl.UniformMatrix3fv(loc.vscale, 1, gl.GL_FALSE, vscale)
      vtranslate[2*3+0] = -1.0 + (2.0/ui.rect.w) * self.rect.x
      vtranslate[2*3+1] = 1.0 - vscale[1*3+1] - (2.0/ui.rect.h) * self.rect.y
      gl.UniformMatrix3fv(loc.vtranslate, 1, gl.GL_FALSE, vtranslate)
      self.texture:BindTexture(gl.GL_TEXTURE_2D)
      local activeTexture = gl.GetInteger(gl.GL_ACTIVE_TEXTURE) - gl.GL_TEXTURE0
      gl.Uniform1i(loc.ftex, activeTexture)
      vbo:BindBuffer()
      gl.EnableVertexAttribArray(loc.vposition)
      gl.VertexAttribPointer(loc.vposition, 2, gl.GL_FLOAT, gl.GL_FALSE, 0, nil)
      gl.EnableVertexAttribArray(loc.vtexcoord)
      gl.VertexAttribPointer(loc.vtexcoord, 2, gl.GL_FLOAT, gl.GL_FALSE, 0, nil)
      gl.DrawArrays(gl.GL_TRIANGLE_STRIP, 0, 4)
   end
   function self:delete()
      rm:delete()
   end
   return self
end

function UI.Text(ui, opts)
   assert(opts.text)
   assert(opts.font)
   local self = ui:Widget(opts)
   local function build_vertex_attribs()
      -- ensure the font's texture atlas is complete
      local line_count = 0
      for line in util.lines(self.text) do
         local cps = iconv.utf8_codepoints(line)
         for i=1,#cps do
            self.font:get_glyph(cps[i])
         end
         line_count = line_count + 1
      end
      -- scaling factors (pixels -> OpenGL coordinates)
      local sx = 1
      local sy = 1
      local tsx = 1 / self.font.atlas.size
      local tsy = 1 / self.font.atlas.size
      -- build vertices and texcoords for all characters
      local vertex_attribs = {}
      local ox = 0
      local oy = -self.font.ascender
      local function add(cp)
         local glyph_data = self.font:get_glyph(cp)
         if glyph_data.width > 0 then
            local x = ox+glyph_data.bearing_x
            local y = oy+glyph_data.bearing_y
            local w = glyph_data.width
            local h = glyph_data.height
            local tw = glyph_data.src_rect.w
            local th = glyph_data.src_rect.h
            local tx = glyph_data.src_rect.x
            local ty = self.font.atlas.size - (glyph_data.src_rect.y + th)
            -- triangle #1 - bottom left
            table.insert(vertex_attribs, x*sx)
            table.insert(vertex_attribs, (y-h)*sy)
            table.insert(vertex_attribs, tx*tsx)
            table.insert(vertex_attribs, ty*tsy)
            -- triangle #1 - top left
            table.insert(vertex_attribs, x*sx)
            table.insert(vertex_attribs, y*sy)
            table.insert(vertex_attribs, tx*tsx)
            table.insert(vertex_attribs, (ty+th)*tsy)
            -- triangle #1 - bottom right
            table.insert(vertex_attribs, (x+w)*sx)
            table.insert(vertex_attribs, (y-h)*sy)
            table.insert(vertex_attribs, (tx+tw)*tsx)
            table.insert(vertex_attribs, ty*tsy)
            -- triangle #2 - bottom right
            table.insert(vertex_attribs, (x+w)*sx)
            table.insert(vertex_attribs, (y-h)*sy)
            table.insert(vertex_attribs, (tx+tw)*tsx)
            table.insert(vertex_attribs, ty*tsy)
            -- triangle #2 - top left
            table.insert(vertex_attribs, x*sx)
            table.insert(vertex_attribs, y*sy)
            table.insert(vertex_attribs, tx*tsx)
            table.insert(vertex_attribs, (ty+th)*tsy)
            -- triangle #2 - top right
            table.insert(vertex_attribs, (x+w)*sx)
            table.insert(vertex_attribs, y*sy)
            table.insert(vertex_attribs, (tx+tw)*tsx)
            table.insert(vertex_attribs, (ty+th)*tsy)
         end
         -- advance
         ox = ox + glyph_data.advance_x
      end
      local function nl()
         ox = 0
         oy = oy - self.font.height
      end
      for line in util.lines(self.text) do
         local cps = iconv.utf8_codepoints(line)
         for i=1,#cps do
            add(cps[i])
         end
         nl()
      end
      return gl.FloatArray(vertex_attribs)
   end
   local rm = gl.ResourceManager()
   local vertex_shader = rm:Shader(gl.GL_VERTEX_SHADER)
   vertex_shader:ShaderSource [[
      #version 120
      attribute vec2 vposition;
      attribute vec2 vtexcoord;
      uniform mat3 vscale;
      uniform mat3 vtranslate;
      varying vec2 ftexcoord;
      void main() {
        ftexcoord = vtexcoord;
        gl_Position = vec4(vtranslate * vscale * vec3(vposition,1.0), 1.0);
      }
   ]]
   vertex_shader:CompileShader()
   local fragment_shader = rm:Shader(gl.GL_FRAGMENT_SHADER)
   fragment_shader:ShaderSource [[
      #version 120
      uniform sampler2D ftex;
      varying vec2 ftexcoord;
      void main() {
         gl_FragColor = texture2D(ftex, ftexcoord);
      }
   ]]
   fragment_shader:CompileShader()
   local shader_program = rm:Program()
   shader_program:AttachShader(vertex_shader)
   shader_program:AttachShader(fragment_shader)
   shader_program:LinkProgram()
   local loc = {
      vposition = shader_program:GetAttribLocation("vposition"),
      vtexcoord = shader_program:GetAttribLocation("vtexcoord"),
      vscale = shader_program:GetUniformLocation("vscale"),
      vtranslate = shader_program:GetUniformLocation("vtranslate"),
      ftex = shader_program:GetUniformLocation("ftex"),
   }
   local vscale = gl.FloatArray {
      1,0,0,
      0,1,0,
      0,0,1,
   }
   local vtranslate = gl.FloatArray {
      1,0,0,
      0,1,0,
      0,0,1,
   }
   local vertex_attribs = build_vertex_attribs()
   local vbo = rm:VBO(ffi.sizeof(vertex_attribs), vertex_attribs, gl.GL_STATIC_DRAW)
   function self:draw()
      gl.UseProgram(shader_program)
      local sx = 2 / ui.rect.w
      local sy = 2 / ui.rect.h
      vscale[0*3+0] = sx
      vscale[1*3+1] = sy
      --pf("vscale=(%s,%s)", vscale[0*3+0], vscale[1*3+1])
      gl.UniformMatrix3fv(loc.vscale, 1, gl.GL_FALSE, vscale)
      vtranslate[2*3+0] = self.rect.x * sx - 1.0
      vtranslate[2*3+1] = 1.0 - self.rect.y * sy
      --pf("vtranslate=(%s,%s)", vtranslate[2*3+0], vtranslate[2*3+1])
      gl.UniformMatrix3fv(loc.vtranslate, 1, gl.GL_FALSE, vtranslate)
      self.font.atlas.texture:BindTexture(gl.GL_TEXTURE_2D)
      local activeTexture = gl.GetInteger(gl.GL_ACTIVE_TEXTURE) - gl.GL_TEXTURE0
      gl.Uniform1i(loc.ftex, activeTexture)
      vbo:BindBuffer()
      local float_size = ffi.sizeof("GLfloat")
      gl.EnableVertexAttribArray(loc.vposition)
      gl.VertexAttribPointer(loc.vposition, 2, gl.GL_FLOAT, gl.GL_FALSE, float_size*4, float_size*0)
      gl.EnableVertexAttribArray(loc.vtexcoord)
      gl.VertexAttribPointer(loc.vtexcoord, 2, gl.GL_FLOAT, gl.GL_FALSE, float_size*4, float_size*2)
      gl.DrawArrays(gl.GL_TRIANGLES, 0, ffi.sizeof(vertex_attribs)/(float_size*4))
   end
   function self:delete()
      rm:delete()
   end
   return self
end

M.UI = UI

local M_mt = {}

function M_mt:__call(...)
   return UI(...)
end

return setmetatable(M, M_mt)
