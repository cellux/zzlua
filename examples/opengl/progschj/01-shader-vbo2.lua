local appfactory = require('appfactory')
local gl = require('gl')
local ffi = require('ffi')

local app = appfactory.OpenGLApp {
   title = "shader-vbo1",
   gl_profile = 'core',
   gl_version = '3.3',
   quit_on_escape = true,
}

function app:init()
   local FS = ffi.sizeof("GLfloat")

   local vertex_shader = gl.CreateShader(gl.GL_VERTEX_SHADER)
   vertex_shader:ShaderSource [[
      #version 330
      in vec4 vposition;
      in vec4 vcolor;
      out vec4 fcolor;
      void main() {
        fcolor = vcolor;
        gl_Position = vposition;
      }
   ]]
   vertex_shader:CompileShader()

   local fragment_shader = gl.CreateShader(gl.GL_FRAGMENT_SHADER)
   fragment_shader:ShaderSource [[
      #version 330
      in vec4 fcolor;
      out vec4 FragColor;
      void main() {
         FragColor = fcolor;
      }
   ]]
   fragment_shader:CompileShader()

   local shader_program = gl.CreateProgram()
   shader_program:AttachShader(vertex_shader)
   shader_program:AttachShader(fragment_shader)
   shader_program:BindAttribLocation(0, "vposition")
   shader_program:BindAttribLocation(1, "vcolor")
   shader_program:BindFragDataLocation(0, "FragColor")
   shader_program:LinkProgram()

   local vao = gl.VertexArray()
   gl.BindVertexArray(vao)
   local vbo = gl.Buffer()
   gl.BindBuffer(gl.GL_ARRAY_BUFFER, vbo)
   local vertex_data = gl.FloatArray {
   --   X    Y    Z          R    G    B
       1.0, 1.0, 0.0,       1.0, 0.0, 0.0, -- vertex 0
      -1.0, 1.0, 0.0,       0.0, 1.0, 0.0, -- vertex 1
       1.0,-1.0, 0.0,       0.0, 0.0, 1.0, -- vertex 2
       1.0,-1.0, 0.0,       0.0, 0.0, 1.0, -- vertex 3
      -1.0, 1.0, 0.0,       0.0, 1.0, 0.0, -- vertex 4
      -1.0,-1.0, 0.0,       1.0, 0.0, 0.0, -- vertex 5
   } -- 6 vertices with 6 components (floats) each
   gl.BufferData(gl.GL_ARRAY_BUFFER,
                 ffi.sizeof(vertex_data), vertex_data,
                 gl.GL_STATIC_DRAW)
   gl.EnableVertexAttribArray(0)
   gl.VertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 6*FS, 0*FS)
   gl.EnableVertexAttribArray(1)
   gl.VertexAttribPointer(1, 3, gl.GL_FLOAT, gl.GL_FALSE, 6*FS, 3*FS)
   gl.BindVertexArray(nil)

   function app:draw()
      gl.Clear(gl.GL_COLOR_BUFFER_BIT)
      gl.UseProgram(shader_program)
      gl.BindVertexArray(vao)
      gl.DrawArrays(gl.GL_TRIANGLES, 0, 6)
   end

   function app:done()
      vao:DeleteVertexArray()
      vbo:DeleteBuffer()
      shader_program:DetachShader(vertex_shader)
      shader_program:DetachShader(fragment_shader)
      vertex_shader:DeleteShader()
      fragment_shader:DeleteShader()
      shader_program:DeleteProgram()
   end
end

app:run()
