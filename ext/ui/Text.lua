local ffi = require('ffi')
local util = require('util')
local iconv = require('iconv')
local gl = require('gl')

local function Text(ui, opts)
   assert(opts.text)
   assert(opts.font)
   local self = ui:Widget(opts)
   local function build_vertex_attribs()
      -- ensure the font's texture atlas is complete
      local line_count = 0
      for line in util.lines(self.text) do
         local cps = iconv.utf8_codepoints(line)
         for i=1,#cps do
            self.font:load_glyph(cps[i])
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
      #version 100
      precision highp float;
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
   if self.font.atlas.texture.format == "rgb" then
      fragment_shader:ShaderSource [[
        #version 100
        precision highp float;
        uniform sampler2D ftex;
        varying vec2 ftexcoord;
        void main() {
           gl_FragColor = texture2D(ftex, ftexcoord);
        }
     ]]
   elseif self.font.atlas.texture.format == "a" then
      fragment_shader:ShaderSource [[
        #version 100
        precision highp float;
        uniform sampler2D ftex;
        varying vec2 ftexcoord;
        void main() {
           float alpha = texture2D(ftex, ftexcoord);
           gl_FragColor = vec4(alpha, alpha, alpha, 1.0);
        }
     ]]
   else
      ef("font atlas has unsupported texture format: %s", self.font.atlas.texture.format)
   end
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

return Text
