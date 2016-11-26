local ffi = require('ffi')
local bit = require('bit')
local gl = require('gl')
local iconv = require('iconv')

local UI = {}

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
         palette[i] = Color(r,g,b)
      end
      palette:upload()
      fg = 7 -- white
      bg = 0 -- black
   end
   self.palette = palette
   local function check_index(index)
      if index < 0 or index >= palette.ncolors then
         ef("color index %s is out of [0,%d] range",
            index, palette.ncolors-1)
      end
      return index
   end
   function self:fg(new_index)
      if new_index then
         fg = check_index(new_index)
      end
      return fg
   end
   function self:bg(new_index)
      if new_index then
         bg = check_index(new_index)
      end
      return bg
   end
   function self:delete()
      if palette then
         palette:delete()
         palette = nil
         self.palette = nil
      end
   end
   return self
end

function UI.CharGrid(ui, opts)
   assert(opts.font)
   assert(opts.width)
   assert(opts.height)
   local cm = CharGridColorManager(ui, opts.palette, opts.fg, opts.bg)
   local self = ui:Widget(opts)
   self.palette = cm.palette
   self.fg = cm.fg
   self.bg = cm.bg
   local grid = nil
   local vertex_buffer_fg = nil
   local vertex_buffer_bg = nil
   local vbo_fg = nil
   local vbo_bg = nil
   local needs_upload = false
   self.font.atlas:on('texture-changed', function()
      needs_upload = true
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
      needs_upload = true
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
   local function upload_vertex_buffer_fg()
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
   local function upload_vertex_buffer_bg()
      vbo_bg:BindBuffer()
      vbo_bg:BufferData(ffi.sizeof(vertex_buffer_bg), vertex_buffer_bg, gl.GL_DYNAMIC_DRAW)
   end
   function self:write_char(x, y, cp)
      local pos = self.width * y + x
      grid[pos].cp = cp
      grid[pos].fg = cm:fg()
      grid[pos].bg = cm:bg()
      -- preload glyph -> resizes font atlas if necessary
      self.font:load_glyph(cp)
      needs_upload = true
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
   function self:upload()
      if needs_upload then
         update_vertex_buffer_fg()
         upload_vertex_buffer_fg()
         update_vertex_buffer_bg()
         upload_vertex_buffer_bg()
         needs_upload = false
      end
   end
   local rm = gl.ResourceManager()
   -- render cell background
   local bg_vertex_shader = rm:Shader(gl.GL_VERTEX_SHADER)
   bg_vertex_shader:ShaderSource [[
      #version 100
      precision highp float;
      attribute vec2 vposition;
      attribute float vcolor; // palette index
      uniform mat3 vscale;
      uniform mat3 vtranslate;
      uniform sampler2D vpalette;
      uniform int vpalettesize;
      varying vec4 fcolor;
      void main() {
        fcolor = texture2D(vpalette, vec2(vcolor / float(vpalettesize), 0));
        gl_Position = vec4(vtranslate * vscale * vec3(vposition, 1.0), 1.0);
      }
   ]]
   bg_vertex_shader:CompileShader()
   local bg_fragment_shader = rm:Shader(gl.GL_FRAGMENT_SHADER)
   bg_fragment_shader:ShaderSource [[
      #version 100
      precision highp float;
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
      #version 100
      precision highp float;
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
        fcolor = texture2D(vpalette, vec2(vcolor / float(vpalettesize), 0));
        gl_Position = vec4(vtranslate * vscale * vec3(vposition, 1.0), 1.0);
      }
   ]]
   fg_vertex_shader:CompileShader()
   local fg_fragment_shader = rm:Shader(gl.GL_FRAGMENT_SHADER)
   fg_fragment_shader:ShaderSource [[
      #version 100
      precision highp float;
      uniform sampler2D ftex;
      varying vec2 ftexcoord;
      varying vec4 fcolor;
      void main() {
        vec4 ftexcolor = texture2D(ftex, ftexcoord);
        gl_FragColor = ftexcolor * fcolor;
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
      self:upload()
      local sx = 2 / ui:width()
      local sy = 2 / ui:height()
      vscale[0*3+0] = sx
      vscale[1*3+1] = -sy -- flip around X to get GL coordinates
      vtranslate[2*3+0] = self.rect.x * sx - 1.0
      vtranslate[2*3+1] = 1.0 - self.rect.y * sy
      gl.ActiveTexture(gl.GL_TEXTURE1)
      cm.palette:BindTexture(gl.GL_TEXTURE_2D)
      gl.ActiveTexture(gl.GL_TEXTURE0)
      self.font.atlas.texture:BindTexture(gl.GL_TEXTURE_2D)
      local float_size = ffi.sizeof("GLfloat")
      -- background
      gl.UseProgram(bg_shader_program)
      gl.UniformMatrix3fv(bg_loc.vscale, 1, gl.GL_FALSE, vscale)
      gl.UniformMatrix3fv(bg_loc.vtranslate, 1, gl.GL_FALSE, vtranslate)
      gl.Uniform1i(bg_loc.vpalette, 1)
      gl.Uniform1i(bg_loc.vpalettesize, cm.palette.ncolors)
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
      gl.Uniform1i(fg_loc.vpalettesize, cm.palette.ncolors)
      gl.Uniform2f(fg_loc.vatlassize, self.font.atlas.size, self.font.atlas.size)
      vbo_fg:BindBuffer()
      gl.EnableVertexAttribArray(fg_loc.vposition)
      gl.VertexAttribPointer(fg_loc.vposition, 2, gl.GL_FLOAT, gl.GL_FALSE, float_size*5, float_size*0)
      gl.EnableVertexAttribArray(fg_loc.vtexcoord)
      gl.VertexAttribPointer(fg_loc.vtexcoord, 2, gl.GL_FLOAT, gl.GL_FALSE, float_size*5, float_size*2)
      gl.EnableVertexAttribArray(fg_loc.vcolor)
      gl.VertexAttribPointer(fg_loc.vcolor, 1, gl.GL_FLOAT, gl.GL_FALSE, float_size*5, float_size*4)
      gl.Enable(gl.GL_BLEND)
      gl.glBlendEquation(gl.GL_FUNC_ADD)
      gl.glBlendFunc(gl.GL_ONE, gl.GL_ONE_MINUS_SRC_COLOR)
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

return UI
