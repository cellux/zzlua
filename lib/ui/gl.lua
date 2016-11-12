local base = require('ui.base')
local gl = require('gl')
local sdl = require('sdl2')
local dim = require('dim')
local iconv = require('iconv')
local util = require('util')
local ffi = require('ffi')
local time = require('time')

local Rect = dim.Rect

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
   gl.TexParameteri(target, gl.GL_TEXTURE_MIN_FILTER, opts.min_filter or gl.GL_LINEAR)
   gl.TexParameteri(target, gl.GL_TEXTURE_MAG_FILTER, opts.mag_filter or gl.GL_LINEAR)
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

function UI.Palette(ui, size)
   local self = {
      palette = ffi.new("uint32_t[?]", size)
   }
   local texture = ui:Texture {
      format = sdl.SDL_PIXELFORMAT_RGBA8888,
      min_filter = gl.GL_NEAREST,
      mag_filter = gl.GL_NEAREST,
      width = size,
      height = 1,
   }
   local pixbuf = ui:PixelBuffer(sdl.SDL_PIXELFORMAT_RGBA8888, size, 1, self.palette)
   function self:index(i, color)
      if ffi.abi("le") then
         self.palette[i] = color:u32le()
      else
         self.palette[i] = color:u32be()
      end
   end
   function self:size()
      return size
   end
   function self:update()
      local src_rect = Rect(0, 0, size, 1)
      local dst_rect = src_rect
      texture:update(dst_rect, pixbuf, src_rect)
   end
   function self:BindTexture(...)
      texture:BindTexture(...)
   end
   function self:texture()
      return texture
   end
   function self:delete()
      if self.palette then
         texture:delete()
         texture = nil
         self.palette = nil
      end
   end
   return self
end

ffi.cdef [[
struct zz_ui_gl_CharGridCell {
  uint32_t cp; // code point
  uint8_t fg;  // foreground color index
  uint8_t bg;  // background color index
};

struct zz_ui_gl_CharGridVertexFG {
  GLfloat x, y, tx, ty, fg;
};

struct zz_ui_gl_CharGridVertexBG {
  GLfloat x, y, bg;
};
]]

local function CharGridColorManager(ui, palette, fg, bg)
   local self = {}
   if not palette then
      palette = ui:Palette(8)
      for i=0,7 do
         local r = bit.band(i, 0x04) == 0 and 0 or 0xFF
         local g = bit.band(i, 0x02) == 0 and 0 or 0xFF
         local b = bit.band(i, 0x01) == 0 and 0 or 0xFF
         palette:index(i, ui:Color(r,g,b))
      end
      palette:update()
      fg = 7 -- white
      bg = 0 -- black
   end
   function self:palette()
      return palette
   end
   function self:fg(new_index)
      if new_index then
         if new_index < 0 or new_index >= palette:size() then
            ef("color index %s is out of [0,%d] range",
               new_index, palette:size()-1)
         end
         fg = new_index
      end
      return fg
   end
   function self:bg(new_index)
      if new_index then
         if new_index < 0 or new_index >= palette:size() then
            ef("color index %s is out of [0,%d] range",
               new_index, palette:size()-1)
         end
         bg = new_index
      end
      return bg
   end
   function self:delete()
      if palette then
         palette:delete()
         palette = nil
      end
   end
   return self
end

function UI.CharGrid(ui, opts)
   assert(opts.font)
   assert(opts.width)
   assert(opts.height)
   local self = ui:Widget(opts)
   local cm = CharGridColorManager(ui, self.palette, self.fg, self.bg)
   self.fg = cm.fg
   self.bg = cm.bg
   self.palette = cm.palette
   local grid = nil
   local vertex_buffer_fg = nil
   local vertex_buffer_bg = nil
   local vbo_fg = nil
   local vbo_bg = nil
   local needs_update = false
   self.font.atlas:on('texture-changed', function()
      needs_update = true
   end)
   function self:resize(new_width, new_height)
      local old_grid, old_width, old_height = grid, self.width, self.height
      grid = ffi.new("struct zz_ui_gl_CharGridCell[?]", new_width * new_height)
      vertex_buffer_fg = ffi.new("struct zz_ui_gl_CharGridVertexFG[?]", new_width * new_height * 6)
      vertex_buffer_bg = ffi.new("struct zz_ui_gl_CharGridVertexBG[?]", new_width * new_height * 6)
      if vbo_fg then
         vbo_fg:delete()
      end
      vbo_fg = gl.VBO()
      if vbo_bg then
         vbo_bg:delete()
      end
      vbo_bg = gl.VBO()
      if old_grid then
         local copy_height = math.min(old_height, new_height)
         local copy_width = math.min(old_width, new_width)
         for y=0,copy_height-1 do
            for x=0,copy_width-1 do
               new_grid[y*new_width+x] = old_grid[y*old_width+x]
            end
         end
      end
      self.width = new_width
      self.height = new_height
      needs_update = true
   end
   self:resize(self.width, self.height)
   local function update_vertex_buffer_fg()
      local ox = 0
      local oy = self.font.ascender
      local vertex_size = ffi.sizeof("struct zz_ui_gl_CharGridVertexFG")
      local vertex_buffer = vertex_buffer_fg
      local vbi = 0 -- vertex buffer index
      local function add(grid_cell)
         local cp, fg = grid_cell.cp, grid_cell.fg
         if cp == 0 then
            cp = 0x20 -- space
         end
         local glyph_data = self.font:get_glyph(cp)
         local x,y,w,h,tx,ty,tw,th
         if glyph_data.width == 0 then
            x = ox
            y = oy-self.font.ascender
            w = self.font.max_advance
            h = self.font.height
            tx = 0
            ty = 0
            tw = 0
            th = 0
         else
            x = ox+glyph_data.bearing_x
            y = oy-glyph_data.bearing_y
            w = glyph_data.width
            h = glyph_data.height
            tx = glyph_data.src_rect.x
            ty = glyph_data.src_rect.y
            tw = glyph_data.src_rect.w
            th = glyph_data.src_rect.h
         end
         -- vertex #1 - triangle #1 - bottom left
         vertex_buffer[vbi].x = x
         vertex_buffer[vbi].y = y+h
         vertex_buffer[vbi].tx = tx
         vertex_buffer[vbi].ty = ty+th
         vertex_buffer[vbi].fg = fg
         vbi = vbi + 1
         -- vertex #2 - triangle #1 - top left
         vertex_buffer[vbi].x = x
         vertex_buffer[vbi].y = y
         vertex_buffer[vbi].tx = tx
         vertex_buffer[vbi].ty = ty
         vertex_buffer[vbi].fg = fg
         vbi = vbi + 1
         -- vertex #3 - triangle #1 - bottom right
         vertex_buffer[vbi].x = x+w
         vertex_buffer[vbi].y = y+h
         vertex_buffer[vbi].tx = tx+tw
         vertex_buffer[vbi].ty = ty+th
         vertex_buffer[vbi].fg = fg
         vbi = vbi + 1
         -- vertex #4 - triangle #2 - bottom right
         vertex_buffer[vbi].x = x+w
         vertex_buffer[vbi].y = y+h
         vertex_buffer[vbi].tx = tx+tw
         vertex_buffer[vbi].ty = ty+th
         vertex_buffer[vbi].fg = fg
         vbi = vbi + 1
         -- vertex #5 - triangle #2 - top left
         vertex_buffer[vbi].x = x
         vertex_buffer[vbi].y = y
         vertex_buffer[vbi].tx = tx
         vertex_buffer[vbi].ty = ty
         vertex_buffer[vbi].fg = fg
         vbi = vbi + 1
         -- vertex #6 - triangle #2 - top right
         vertex_buffer[vbi].x = x+w
         vertex_buffer[vbi].y = y
         vertex_buffer[vbi].tx = tx+tw
         vertex_buffer[vbi].ty = ty
         vertex_buffer[vbi].fg = fg
         vbi = vbi + 1
         -- advance
         ox = ox + self.font.max_advance
      end
      local function nl()
         ox = 0
         oy = oy + self.font.height
      end
      local w, h = self.width, self.height
      for y=0,h-1 do
         for x=0,w-1 do
            add(grid[y*w+x])
         end
         nl()
      end
   end
   local function update_vbo_fg()
      vbo_fg:BindBuffer()
      vbo_fg:BufferData(ffi.sizeof(vertex_buffer_fg), vertex_buffer_fg, gl.GL_DYNAMIC_DRAW)
   end
   local function update_vertex_buffer_bg()
      local ox = 0
      local oy = 0
      local vertex_size = ffi.sizeof("struct zz_ui_gl_CharGridVertexBG")
      local vertex_buffer = vertex_buffer_bg
      local vbi = 0 -- vertex buffer index
      local function add(grid_cell)
         local x = ox
         local y = oy
         local w = self.font.max_advance
         local h = self.font.height
         local bg = grid_cell.bg
         -- vertex #1 - triangle #1 - bottom left
         vertex_buffer[vbi].x = x
         vertex_buffer[vbi].y = y+h
         vertex_buffer[vbi].bg = bg
         vbi = vbi + 1
         -- vertex #2 - triangle #1 - top left
         vertex_buffer[vbi].x = x
         vertex_buffer[vbi].y = y
         vertex_buffer[vbi].bg = bg
         vbi = vbi + 1
         -- vertex #3 - triangle #1 - bottom right
         vertex_buffer[vbi].x = x+w
         vertex_buffer[vbi].y = y+h
         vertex_buffer[vbi].bg = bg
         vbi = vbi + 1
         -- vertex #4 - triangle #2 - bottom right
         vertex_buffer[vbi].x = x+w
         vertex_buffer[vbi].y = y+h
         vertex_buffer[vbi].bg = bg
         vbi = vbi + 1
         -- vertex #5 - triangle #2 - top left
         vertex_buffer[vbi].x = x
         vertex_buffer[vbi].y = y
         vertex_buffer[vbi].bg = bg
         vbi = vbi + 1
         -- vertex #6 - triangle #2 - top right
         vertex_buffer[vbi].x = x+w
         vertex_buffer[vbi].y = y
         vertex_buffer[vbi].bg = bg
         vbi = vbi + 1
         -- advance
         ox = ox + w
      end
      local function nl()
         ox = 0
         oy = oy + self.font.height
      end
      local w, h = self.width, self.height
      for y=0,h-1 do
         for x=0,w-1 do
            add(grid[y*w+x])
         end
         nl()
      end
   end
   local function update_vbo_bg()
      vbo_bg:BindBuffer()
      vbo_bg:BufferData(ffi.sizeof(vertex_buffer_bg), vertex_buffer_bg, gl.GL_DYNAMIC_DRAW)
   end
   function self:write_char(x, y, cp)
      local pos = self.width * y + x
      if pos >= (ffi.sizeof(grid) / ffi.sizeof("struct zz_ui_gl_CharGridCell")) then
         ef("x=%d, y=%d, cp=%d", x, y, cp)
      end
      assert((pos*6) < (ffi.sizeof(vertex_buffer_fg) / ffi.sizeof("struct zz_ui_gl_CharGridVertexFG")))
      assert((pos*6) < (ffi.sizeof(vertex_buffer_bg) / ffi.sizeof("struct zz_ui_gl_CharGridVertexBG")))
      grid[pos].cp = cp
      grid[pos].fg = cm:fg()
      grid[pos].bg = cm:bg()
      -- preload glyph -> resizes font atlas if necessary
      self.font:load_glyph(cp)
      needs_update = true
   end
   function self:write(x, y, str)
      local cps = iconv.utf8_codepoints(str)
      for i=1,#cps do
         self:write_char(x+i-1, y, cps[i])
      end
   end
   function self:erase_row(y)
      for x=0,self.width-1 do
         self:write_char(x, y, 0x20)
      end
   end
   function self:scroll_up()
      local dst = grid
      local src = grid + self.width
      local pitch = self.width * ffi.sizeof("struct zz_ui_gl_CharGridCell")
      ffi.copy(dst, src, (self.height-1) * pitch)
      self:erase_row(self.height-1)
   end
   function self:update()
      if needs_update then
         update_vertex_buffer_fg()
         update_vertex_buffer_bg()
         update_vbo_fg()
         update_vbo_bg()
         needs_update = false
      end
   end
   local rm = gl.ResourceManager()
   -- render cell background
   local bg_vertex_shader = rm:Shader(gl.GL_VERTEX_SHADER)
   bg_vertex_shader:ShaderSource [[
      #version 120
      attribute vec2 vposition;
      attribute float vcolor; // palette index
      uniform mat3 vscale;
      uniform mat3 vtranslate;
      uniform sampler2D vpalette;
      uniform int vpalettesize;
      varying vec4 fcolor;
      void main() {
        fcolor = texture2D(vpalette, vec2(vcolor/vpalettesize, 0));
        gl_Position = vec4(vtranslate * vscale * vec3(vposition, 1.0), 1.0);
      }
   ]]
   bg_vertex_shader:CompileShader()
   local bg_fragment_shader = rm:Shader(gl.GL_FRAGMENT_SHADER)
   bg_fragment_shader:ShaderSource [[
      #version 120
      varying vec4 fcolor;
      void main() {
         gl_FragColor = fcolor;
      }
   ]]
   bg_fragment_shader:CompileShader()
   local bg_shader_program = rm:Program()
   bg_shader_program:AttachShader(bg_vertex_shader)
   bg_shader_program:AttachShader(bg_fragment_shader)
   bg_shader_program:LinkProgram()
   local bg_loc = {
      vposition = bg_shader_program:GetAttribLocation("vposition"),
      vcolor = bg_shader_program:GetAttribLocation("vcolor"),
      vscale = bg_shader_program:GetUniformLocation("vscale"),
      vtranslate = bg_shader_program:GetUniformLocation("vtranslate"),
      vpalette = bg_shader_program:GetUniformLocation("vpalette"),
      vpalettesize = bg_shader_program:GetUniformLocation("vpalettesize"),
   }
   -- render cell foreground (glyphs)
   local fg_vertex_shader = rm:Shader(gl.GL_VERTEX_SHADER)
   fg_vertex_shader:ShaderSource [[
      #version 120
      attribute vec2 vposition;
      attribute vec2 vtexcoord;
      attribute float vcolor; // palette index
      uniform mat3 vscale;
      uniform mat3 vtranslate;
      uniform sampler2D vpalette;
      uniform int vpalettesize;
      uniform vec2 vatlassize;
      varying vec2 ftexcoord;
      varying vec4 fcolor;
      void main() {
        ftexcoord.x = vtexcoord.x / vatlassize.x;
        ftexcoord.y = 1.0 - vtexcoord.y / vatlassize.y;
        fcolor = texture2D(vpalette, vec2(vcolor/vpalettesize, 0));
        gl_Position = vec4(vtranslate * vscale * vec3(vposition, 1.0), 1.0);
      }
   ]]
   fg_vertex_shader:CompileShader()
   local fg_fragment_shader = rm:Shader(gl.GL_FRAGMENT_SHADER)
   fg_fragment_shader:ShaderSource [[
      #version 120
      uniform sampler2D ftex;
      varying vec2 ftexcoord;
      varying vec4 fcolor;
      void main() {
        vec4 ftexcolor = texture2D(ftex, ftexcoord);
        if (ftexcolor.a == 0) {
          discard;
        }
        else {
          gl_FragColor = ftexcolor * fcolor;
        }
      }
   ]]
   fg_fragment_shader:CompileShader()
   local fg_shader_program = rm:Program()
   fg_shader_program:AttachShader(fg_vertex_shader)
   fg_shader_program:AttachShader(fg_fragment_shader)
   fg_shader_program:LinkProgram()
   local fg_loc = {
      vposition = fg_shader_program:GetAttribLocation("vposition"),
      vtexcoord = fg_shader_program:GetAttribLocation("vtexcoord"),
      vcolor = fg_shader_program:GetAttribLocation("vcolor"),
      vatlassize = fg_shader_program:GetUniformLocation("vatlassize"),
      vscale = fg_shader_program:GetUniformLocation("vscale"),
      vtranslate = fg_shader_program:GetUniformLocation("vtranslate"),
      vpalette = fg_shader_program:GetUniformLocation("vpalette"),
      vpalettesize = fg_shader_program:GetUniformLocation("vpalettesize"),
      ftex = fg_shader_program:GetUniformLocation("ftex"),
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
   function self:draw()
      self:update()
      local sx = 2 / ui.rect.w
      local sy = 2 / ui.rect.h
      vscale[0*3+0] = sx
      vscale[1*3+1] = -sy -- flip around X to get GL coordinates
      vtranslate[2*3+0] = self.rect.x * sx - 1.0
      vtranslate[2*3+1] = 1.0 - self.rect.y * sy
      gl.ActiveTexture(gl.GL_TEXTURE1)
      cm:palette():BindTexture(gl.GL_TEXTURE_2D)
      gl.ActiveTexture(gl.GL_TEXTURE0)
      self.font.atlas.texture:BindTexture(gl.GL_TEXTURE_2D)
      local float_size = ffi.sizeof("GLfloat")
      -- background
      gl.UseProgram(bg_shader_program)
      gl.UniformMatrix3fv(bg_loc.vscale, 1, gl.GL_FALSE, vscale)
      gl.UniformMatrix3fv(bg_loc.vtranslate, 1, gl.GL_FALSE, vtranslate)
      gl.Uniform1i(bg_loc.vpalette, 1)
      gl.Uniform1i(bg_loc.vpalettesize, cm:palette():size())
      vbo_bg:BindBuffer()
      gl.EnableVertexAttribArray(bg_loc.vposition)
      gl.VertexAttribPointer(bg_loc.vposition, 2, gl.GL_FLOAT, gl.GL_FALSE, float_size*3, float_size*0)
      gl.EnableVertexAttribArray(bg_loc.vcolor)
      gl.VertexAttribPointer(bg_loc.vcolor, 1, gl.GL_FLOAT, gl.GL_FALSE, float_size*3, float_size*2)
      gl.Disable(gl.GL_BLEND)
      gl.DrawArrays(gl.GL_TRIANGLES, 0, ffi.sizeof(vertex_buffer_bg)/(float_size*3))
      -- foreground
      gl.UseProgram(fg_shader_program)
      gl.UniformMatrix3fv(fg_loc.vscale, 1, gl.GL_FALSE, vscale)
      gl.UniformMatrix3fv(fg_loc.vtranslate, 1, gl.GL_FALSE, vtranslate)
      gl.Uniform1i(fg_loc.ftex, 0)
      gl.Uniform1i(fg_loc.vpalette, 1)
      gl.Uniform1i(fg_loc.vpalettesize, cm:palette():size())
      gl.Uniform2f(fg_loc.vatlassize, self.font.atlas.size, self.font.atlas.size)
      vbo_fg:BindBuffer()
      gl.EnableVertexAttribArray(fg_loc.vposition)
      gl.VertexAttribPointer(fg_loc.vposition, 2, gl.GL_FLOAT, gl.GL_FALSE, float_size*5, float_size*0)
      gl.EnableVertexAttribArray(fg_loc.vtexcoord)
      gl.VertexAttribPointer(fg_loc.vtexcoord, 2, gl.GL_FLOAT, gl.GL_FALSE, float_size*5, float_size*2)
      gl.EnableVertexAttribArray(fg_loc.vcolor)
      gl.VertexAttribPointer(fg_loc.vcolor, 1, gl.GL_FLOAT, gl.GL_FALSE, float_size*5, float_size*4)
      gl.Enable(gl.GL_BLEND)
      gl.DrawArrays(gl.GL_TRIANGLES, 0, ffi.sizeof(vertex_buffer_fg)/(float_size*5))
   end
   function self:delete()
      if vbo_fg then
         vbo_fg:delete()
         vbo_fg = nil
      end
      if vbo_bg then
         vbo_bg:delete()
         vbo_bg = nil
      end
      if rm then
         rm:delete()
         rm = nil
      end
      if cm then
         cm:delete()
         cm = nil
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
