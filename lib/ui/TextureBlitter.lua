local ffi = require('ffi')
local gl = require('gl')

local UI = {}

function UI.TextureBlitter(ui, opts)
   opts = opts or {}
   local self = {}
   self.gl_Position = opts.gl_Position
   if not self.gl_Position then
      self.gl_Position = [[
        return vec4(vtranslate * vscale * vec3(vposition, 1.0), 1.0);
      ]]
   end
   self.gl_FragColor = opts.gl_FragColor
   if not self.gl_FragColor then
      self.gl_FragColor = [[
        return texture2D(ftex, ftexcoord);
      ]]
   end
   local rm = gl.ResourceManager()
   local vertex_shader = rm:Shader(gl.GL_VERTEX_SHADER)
   vertex_shader:ShaderSource([[
      #version 100
      precision highp float;
      attribute vec2 vposition;
      attribute vec2 vtexcoord;
      uniform mat3 vscale;
      uniform mat3 vtranslate;
      varying vec2 ftexcoord;
      vec4 calculate_gl_Position() {
      ]] .. self.gl_Position .. [[
      }
      void main() {
        ftexcoord = vtexcoord;
        gl_Position = calculate_gl_Position();
      }
   ]])
   vertex_shader:CompileShader()
   local fragment_shader = rm:Shader(gl.GL_FRAGMENT_SHADER)
   fragment_shader:ShaderSource([[
      #version 100
      precision highp float;
      uniform sampler2D ftex;
      varying vec2 ftexcoord;
      vec4 calculate_gl_FragColor() {
      ]] .. self.gl_FragColor .. [[
      }
      void main() {
         gl_FragColor = calculate_gl_FragColor();
      }
   ]])
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
   -- x, y, s, t  -- still in screen coords
      0, 1, 0, 1, -- bottom left
      0, 0, 0, 0, -- top left
      1, 1, 1, 1, -- bottom right
      1, 0, 1, 0, -- top right
   }
   local vbo = rm:VBO()
   function self:blit(texture, dst_rect, src_rect)
      gl.UseProgram(shader_program)
      local sx = 2.0 / ui:width()
      local sy = 2.0 / ui:height()
      vscale[0*3+0] = sx * dst_rect.w
      vscale[1*3+1] = -sy * dst_rect.h -- OpenGL y increases bottom->up
      gl.UniformMatrix3fv(loc.vscale, 1, gl.GL_FALSE, vscale)
      vtranslate[2*3+0] = -1.0 + sx * dst_rect.x
      vtranslate[2*3+1] = 1.0 - sy * dst_rect.y
      gl.UniformMatrix3fv(loc.vtranslate, 1, gl.GL_FALSE, vtranslate)
      texture:BindTexture(gl.GL_TEXTURE_2D)
      local activeTexture = gl.GetInteger(gl.GL_ACTIVE_TEXTURE) - gl.GL_TEXTURE0
      gl.Uniform1i(loc.ftex, activeTexture)
      vbo:BindBuffer()
      if src_rect then
         -- convert to OpenGL texture coordinates
         local x1 = src_rect.x / texture.width
         local y1 = (texture.height - src_rect.y) / texture.height
         local x2 = (src_rect.x + src_rect.w) / texture.width
         local y2 = (texture.height - (src_rect.y + src_rect.h)) / texture.height
         -- bottom left
         vertex_data[4*0+2] = x1
         vertex_data[4*0+3] = y2
         -- top left
         vertex_data[4*1+2] = x1
         vertex_data[4*1+3] = y1
         -- bottom right
         vertex_data[4*2+2] = x2
         vertex_data[4*2+3] = y2
         -- top right
         vertex_data[4*3+2] = x2
         vertex_data[4*3+3] = y1
      else
         -- bottom left
         vertex_data[4*0+2] = 0
         vertex_data[4*0+3] = 0
         -- top left
         vertex_data[4*1+2] = 0
         vertex_data[4*1+3] = 1
         -- bottom right
         vertex_data[4*2+2] = 1
         vertex_data[4*2+3] = 0
         -- top right
         vertex_data[4*3+2] = 1
         vertex_data[4*3+3] = 1
      end
      vbo:BufferData(ffi.sizeof(vertex_data), vertex_data, gl.GL_DYNAMIC_DRAW)
      local float_size = ffi.sizeof("GLfloat")
      gl.EnableVertexAttribArray(loc.vposition)
      gl.VertexAttribPointer(loc.vposition, 2, gl.GL_FLOAT, gl.GL_FALSE, float_size*4, float_size*0)
      gl.EnableVertexAttribArray(loc.vtexcoord)
      gl.VertexAttribPointer(loc.vtexcoord, 2, gl.GL_FLOAT, gl.GL_FALSE, float_size*4, float_size*2)
      gl.DrawArrays(gl.GL_TRIANGLE_STRIP, 0, 4)
   end
   function self:blend(texture, dst_rect, src_rect,
                       blend_equation, blend_func_src, blend_func_dst)
      if texture.has_alpha then
         gl.glEnable(gl.GL_BLEND)
         gl.glBlendEquation(blend_equation or gl.GL_FUNC_ADD)
         gl.glBlendFunc(blend_func_src or gl.GL_SRC_ALPHA,
                        blend_func_dst or gl.GL_ONE_MINUS_SRC_ALPHA)
      else
         gl.glDisable(gl.GL_BLEND)
      end
      self:blit(texture, dst_rect, src_rect)
   end
   function self:delete()
      rm:delete()
   end
   return self
end

return UI
