local engine = require('engine')
local gl = require('gl')
local ffi = require('ffi')

local app = engine.OpenGLApp { title = "shader-vbo1" }

function app:init()
   local FS = ffi.sizeof("GLfloat")

   local rm = gl.ResourceManager()

   local vertex_shader = rm:CreateShader(gl.GL_VERTEX_SHADER)
   vertex_shader:source [[
      #version 330
      layout (location = 0) in vec4 vposition;
      layout (location = 1) in vec4 vcolor;
      out vec4 fcolor;
      void main() {
        fcolor = vcolor;
        gl_Position = vposition;
      }
   ]]
   vertex_shader:compile()

   local fragment_shader = rm:CreateShader(gl.GL_FRAGMENT_SHADER)
   fragment_shader:source [[
      #version 330
      in vec4 fcolor;
      layout (location = 0) out vec4 FragColor;
      void main() {
         FragColor = fcolor;
      }
   ]]
   fragment_shader:compile()

   local shader_program = rm:CreateProgram()
   shader_program:attach(vertex_shader)
   shader_program:attach(fragment_shader)
   shader_program:bindAttribLocation(0, "vposition")
   shader_program:bindAttribLocation(1, "vcolor")
   shader_program:bindFragDataLocation(0, "FragColor")
   shader_program:link()

   local vao = rm:VAO()
   gl.BindVertexArray(vao)
   local vbo = rm:VBO()
   gl.BindBuffer(gl.GL_ARRAY_BUFFER, vbo)
   local vertex_data = gl.FloatArray {
   --   X    Y    Z          R    G    B
       1.0, 1.0, 0.0,       1.0, 0.0, 0.0, -- vertex 0
      -1.0, 1.0, 0.0,       0.0, 1.0, 0.0, -- vertex 1
       1.0,-1.0, 0.0,       0.0, 0.0, 1.0, -- vertex 2
      -1.0,-1.0, 0.0,       1.0, 0.0, 0.0, -- vertex 3
   } -- 4 vertices with 6 components (floats) each
   gl.BufferData(gl.GL_ARRAY_BUFFER,
                 ffi.sizeof(vertex_data), vertex_data,
                 gl.GL_STATIC_DRAW)
   gl.EnableVertexAttribArray(0)
   gl.VertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 6*FS, 0*FS)
   gl.EnableVertexAttribArray(1)
   gl.VertexAttribPointer(1, 3, gl.GL_FLOAT, gl.GL_FALSE, 6*FS, 3*FS)
   local ibo = rm:VBO()
   gl.BindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ibo)
   local index_data = gl.UIntArray {
      0,1,2, -- first triangle
      2,1,3, -- second triangle
   }
   gl.BufferData(gl.GL_ELEMENT_ARRAY_BUFFER,
                 ffi.sizeof(index_data), index_data,
                 gl.GL_STATIC_DRAW)
   gl.BindVertexArray(nil)

   function app:draw()
      gl.Clear(gl.GL_COLOR_BUFFER_BIT)
      gl.UseProgram(shader_program)
      gl.BindVertexArray(vao)
      gl.DrawElements(gl.GL_TRIANGLES, 6, gl.GL_UNSIGNED_INT, 0)
   end

   function app:done()
      rm:delete()
   end
end

app:run()
