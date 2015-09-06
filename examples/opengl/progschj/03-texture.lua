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
      layout (location = 1) in vec2 vtexcoord;
      out vec2 ftexcoord;
      void main() {
        ftexcoord = vtexcoord;
        gl_Position = vposition;
      }
   ]]
   vertex_shader:compile()

   local fragment_shader = rm:CreateShader(gl.GL_FRAGMENT_SHADER)
   fragment_shader:source [[
      #version 330
      uniform sampler2D tex;
      in vec2 ftexcoord;
      layout (location = 0) out vec4 FragColor;
      void main() {
         FragColor = texture(tex, ftexcoord);
      }
   ]]
   fragment_shader:compile()

   local shader_program = rm:CreateProgram()
   shader_program:attach(vertex_shader)
   shader_program:attach(fragment_shader)
   shader_program:link()
   local texture_location = shader_program:getUniformLocation("tex")

   local vao = rm:VAO()
   gl.BindVertexArray(vao)
   local vbo = rm:VBO()
   gl.BindBuffer(gl.GL_ARRAY_BUFFER, vbo)
   local vertex_data = gl.FloatArray {
   --   X    Y    Z          U    V
       1.0, 1.0, 0.0,       1.0, 1.0, -- vertex 0
      -1.0, 1.0, 0.0,       0.0, 1.0, -- vertex 1
       1.0,-1.0, 0.0,       1.0, 0.0, -- vertex 2
      -1.0,-1.0, 0.0,       0.0, 0.0, -- vertex 3
   } -- 4 vertices with 5 components (floats) each
   gl.BufferData(gl.GL_ARRAY_BUFFER,
                 ffi.sizeof(vertex_data), vertex_data,
                 gl.GL_STATIC_DRAW)
   gl.EnableVertexAttribArray(0)
   gl.VertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 5*FS, 0*FS)
   gl.EnableVertexAttribArray(1)
   gl.VertexAttribPointer(1, 2, gl.GL_FLOAT, gl.GL_FALSE, 5*FS, 3*FS)
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

   local texture = rm:Texture()
   gl.BindTexture(gl.GL_TEXTURE_2D, texture)
   local width, height = self.w, self.h
   local image = ffi.new("GLubyte[?]", 4*width*height)
   for y=0,height-1 do
      for x=0,width-1 do
         local index = y*width+x
         image[4*index+0] = 0xFF*(y/10%2)*(x/10%2) -- R
         image[4*index+1] = 0xFF*(y/13%2)*(x/13%2) -- G
         image[4*index+2] = 0xFF*(y/17%2)*(x/17%2) -- B
         image[4*index+3] = 0xFF                    -- A
      end
   end
   gl.TexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
   gl.TexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
   gl.TexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
   gl.TexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
   gl.TexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RGBA8, self.w, self.h, 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, image)

   function app:draw()
      gl.Clear(gl.GL_COLOR_BUFFER_BIT)
      gl.UseProgram(shader_program)
      gl.ActiveTexture(gl.GL_TEXTURE0)
      gl.BindTexture(gl.GL_TEXTURE_2D, texture)
      gl.Uniform1i(texture_location, 0)
      gl.BindVertexArray(vao)
      gl.DrawElements(gl.GL_TRIANGLES, 6, gl.GL_UNSIGNED_INT, 0)
   end

   function app:done()
      rm:delete()
   end
end

app:run()
