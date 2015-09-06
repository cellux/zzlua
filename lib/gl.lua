local ffi = require('ffi')
local util = require('util')
local adt = require('adt')

ffi.cdef [[

typedef signed   char          khronos_int8_t;
typedef unsigned char          khronos_uint8_t;
typedef signed   short int     khronos_int16_t;
typedef unsigned short int     khronos_uint16_t;
typedef int32_t                khronos_int32_t;
typedef uint32_t               khronos_uint32_t;
typedef int64_t                khronos_int64_t;
typedef uint64_t               khronos_uint64_t;
typedef float                  khronos_float_t;

typedef void             GLvoid;
typedef char             GLchar;
typedef unsigned int     GLenum;
typedef unsigned char    GLboolean;
typedef unsigned int     GLbitfield;
typedef khronos_int8_t   GLbyte;
typedef short            GLshort;
typedef int              GLint;
typedef int              GLsizei;
typedef khronos_uint8_t  GLubyte;
typedef unsigned short   GLushort;
typedef unsigned int     GLuint;
typedef khronos_float_t  GLfloat;
typedef khronos_float_t  GLclampf;
typedef khronos_int32_t  GLfixed;

typedef ptrdiff_t        GLsizeiptr;

enum {
  GL_FALSE = 0,
  GL_TRUE  = 1
};

enum {
  GL_BYTE           = 0x1400,
  GL_UNSIGNED_BYTE  = 0x1401,
  GL_SHORT          = 0x1402,
  GL_UNSIGNED_SHORT = 0x1403,
  GL_INT            = 0x1404,
  GL_UNSIGNED_INT   = 0x1405,
  GL_FLOAT          = 0x1406,
  GL_DOUBLE         = 0x140A,
  GL_HALF_FLOAT     = 0x140B,
  GL_FIXED          = 0x140C
};

/* Errors */

enum {
  GL_NO_ERROR          = 0,
  GL_INVALID_ENUM      = 0x0500,
  GL_INVALID_VALUE     = 0x0501,
  GL_INVALID_OPERATION = 0x0502,
  GL_STACK_OVERFLOW    = 0x0503,
  GL_STACK_UNDERFLOW   = 0x0504,
  GL_OUT_OF_MEMORY     = 0x0505
};

GLenum glGetError (void);

enum {
  GL_FRAGMENT_SHADER = 0x8B30,
  GL_VERTEX_SHADER   = 0x8B31,
  GL_GEOMETRY_SHADER = 0x8DD9
};

enum {
  GL_COMPILE_STATUS  = 0x8B81,
  GL_LINK_STATUS     = 0x8B82,
  GL_VALIDATE_STATUS = 0x8B83,
  GL_INFO_LOG_LENGTH = 0x8B84
};

enum {
  GL_ARRAY_BUFFER              = 0x8892,
  GL_ELEMENT_ARRAY_BUFFER      = 0x8893,
  GL_UNIFORM_BUFFER            = 0x8A11,
  GL_COPY_READ_BUFFER          = 0x8F36,
  GL_COPY_WRITE_BUFFER         = 0x8F37,
  GL_DRAW_INDIRECT_BUFFER      = 0x8F3F,
  GL_PIXEL_PACK_BUFFER         = 0x88EB,
  GL_PIXEL_UNPACK_BUFFER       = 0x88EC,
  GL_TEXTURE_BUFFER            = 0x8C2A,
  GL_TRANSFORM_FEEDBACK_BUFFER = 0x8C8E,
  GL_SHADER_STORAGE_BUFFER     = 0x90D2,
  GL_DISPATCH_INDIRECT_BUFFER  = 0x90EE,
  GL_ATOMIC_COUNTER_BUFFER     = 0x92C0
};

enum {
  GL_STREAM_DRAW  = 0x88E0,
  GL_STREAM_READ  = 0x88E1,
  GL_STREAM_COPY  = 0x88E2,
  GL_STATIC_DRAW  = 0x88E4,
  GL_STATIC_READ  = 0x88E5,
  GL_STATIC_COPY  = 0x88E6,
  GL_DYNAMIC_DRAW = 0x88E8,
  GL_DYNAMIC_READ = 0x88E9,
  GL_DYNAMIC_COPY = 0x88EA
};

GLuint glCreateShader (GLenum type);
void glShaderSource (GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length);
void glCompileShader (GLuint shader);
void glGetShaderiv (GLuint shader, GLenum pname, GLint *params);
void glGetShaderInfoLog (GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
void glDeleteShader (GLuint shader);

GLuint glCreateProgram (void);
void glAttachShader (GLuint program, GLuint shader);
void glBindAttribLocation (GLuint program, GLuint index, const GLchar *name);
void glBindFragDataLocation (GLuint program, GLuint color, const GLchar *name);
void glLinkProgram (GLuint program);
void glUseProgram (GLuint program);
void glGetProgramiv (GLuint program, GLenum pname, GLint *params);
void glGetProgramInfoLog (GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
void glDetachShader (GLuint program, GLuint shader);
void glDeleteProgram (GLuint program);

void glGenVertexArrays (GLsizei n, GLuint *arrays);
void glBindVertexArray (GLuint array);
void glDeleteVertexArrays (GLsizei n, const GLuint *arrays);

void glEnableVertexAttribArray (GLuint index);
void glDisableVertexAttribArray (GLuint index);

void glVertexAttribPointer (GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer);

void glGenBuffers (GLsizei n, GLuint *buffers);
void glBindBuffer (GLenum target, GLuint buffer);
void glDeleteBuffers (GLsizei n, const GLuint *buffers);

void glBufferData (GLenum target, GLsizeiptr size, const void *data, GLenum usage);

enum {
  GL_COLOR_BUFFER_BIT   = 0x00004000,
  GL_DEPTH_BUFFER_BIT   = 0x00000100,
  GL_STENCIL_BUFFER_BIT = 0x00000400
};

void glClear (GLbitfield mask);

enum {
  GL_POINTS         = 0x0000,
  GL_LINES          = 0x0001,
  GL_LINE_LOOP      = 0x0002,
  GL_LINE_STRIP     = 0x0003,
  GL_TRIANGLES      = 0x0004,
  GL_TRIANGLE_STRIP = 0x0005,
  GL_TRIANGLE_FAN   = 0x0006,
  GL_QUADS          = 0x0007,
  GL_QUAD_STRIP     = 0x0008,
  GL_POLYGON        = 0x0009
};

void glDrawArrays (GLenum mode, GLint first, GLsizei count);
void glDrawElements (GLenum mode, GLsizei count, GLenum type, const void *indices);

]]

local M = {}

M.GetError = ffi.C.glGetError

local Shader_mt = {}

function Shader_mt:source(text)
   local str = ffi.new("GLchar*[1]", ffi.cast("GLchar*", text))
   local len = ffi.new("GLint[1]", #text)
   ffi.C.glShaderSource(self.id,
                        1,
                        ffi.cast("const GLchar * const *", str),
                        len)
end

function Shader_mt:compile()
   ffi.C.glCompileShader(self.id)
   local status = ffi.new("GLint[1]")
   ffi.C.glGetShaderiv(self.id, ffi.C.GL_COMPILE_STATUS, status)
   if status == ffi.C.GL_FALSE then
      ef("glCompileShader() failed: %s", self:info_log())
   end
end

function Shader_mt:info_log()
   local length = ffi.new("GLint[1]")
   ffi.C.glGetShaderiv(self.id, ffi.C.GL_INFO_LOG_LENGTH, length)
   local log = ffi.new("GLchar[?]", length[0])
   local log_len = ffi.new("GLsizei[1]")
   ffi.C.glGetShaderInfoLog(self.id, length[0], log_len, log)
   return ffi.string(log, log_len[0])
end

function Shader_mt:delete()
   if self.id then
      ffi.C.glDeleteShader(self.id)
      self.id = nil
   end
end

Shader_mt.__index = Shader_mt
Shader_mt.__gc = Shader_mt.delete

function M.CreateShader(type)
   local id = util.check_bad("glCreateShader", 0, ffi.C.glCreateShader(type))
   local self = { type = type, id = id }
   return setmetatable(self, Shader_mt)
end

local Program_mt = {}

function Program_mt:attach(shader)
   ffi.C.glAttachShader(self.id, shader.id)
   self.shaders:push(shader)
end

function Program_mt:detach(shader)
   ffi.C.glDetachShader(self.id, shader.id)
   self.shaders:remove(shader)
end

function Program_mt:detach_all()
   for shader in self.shaders:itervalues() do
      ffi.C.glDetachShader(self.id, shader.id)
   end
   self.shaders = adt.List()
end

function Program_mt:bindAttribLocation(index, name)
   ffi.C.glBindAttribLocation(self.id, index, name)
end

function Program_mt:bindFragDataLocation(index, name)
   ffi.C.glBindFragDataLocation(self.id, index, name)
end

function Program_mt:link()
   ffi.C.glLinkProgram(self.id)
   local status = ffi.new("GLint[1]")
   ffi.C.glGetProgramiv(self.id, ffi.C.GL_LINK_STATUS, status)
   if status == ffi.C.GL_FALSE then
      ef("glLinkProgram() failed: %s", self:info_log())
   end
end

function Program_mt:info_log()
   local length = ffi.new("GLint[1]")
   ffi.C.glGetProgramiv(self.id, ffi.C.GL_INFO_LOG_LENGTH, length)
   local log = ffi.new("GLchar[?]", length[0])
   local log_len = ffi.new("GLsizei[1]")
   ffi.C.glGetProgramInfoLog(self.id, length[0], log_len, log)
   return ffi.string(log, log_len[0])
end

function Program_mt:delete()
   if self.id then
      ffi.C.glDeleteProgram(self.id)
      self.id = nil
   end
end

Program_mt.__index = Program_mt
Program_mt.__gc = Program_mt.delete

function M.CreateProgram()
   local id = util.check_bad("glCreateProgram", 0, ffi.C.glCreateProgram())
   local self = { id = id, shaders = adt.List() }
   return setmetatable(self, Program_mt)
end

-- VertexArray (VAO)

local VAO_mt = {}

function VAO_mt:delete()
   if self.id then
      local arrays = ffi.new("GLuint[1]", self.id)
      ffi.C.glDeleteVertexArrays(1, arrays)
      self.id = nil
   end
end
   
VAO_mt.__index = VAO_mt
VAO_mt.__gc = VAO_mt.delete

function M.VAO()
   local arrays = ffi.new("GLuint[1]")
   ffi.C.glGenVertexArrays(1, arrays)
   local self = { id = arrays[0] }
   return setmetatable(self, VAO_mt)
end

function M.BindVertexArray(array)
   ffi.C.glBindVertexArray(array and array.id or 0)
end

-- VertexBuffer (VBO)

local VBO_mt = {}

function VBO_mt:delete()
   if self.id then
      local buffers = ffi.new("GLuint[1]", self.id)
      ffi.C.glDeleteBuffers(1, buffers)
      self.id = nil
   end
end

VBO_mt.__index = VBO_mt
VBO_mt.__gc = VBO_mt.delete

function M.VBO()
   local buffers = ffi.new("GLuint[1]")
   ffi.C.glGenBuffers(1, buffers)
   local self = { id = buffers[0] }
   return setmetatable(self, VBO_mt)
end

function M.BindBuffer(target, buffer)
   ffi.C.glBindBuffer(target, buffer.id)
end

function M.FloatArray(elements)
   return ffi.new("GLfloat[?]", #elements, elements)
end

function M.UIntArray(elements)
   return ffi.new("GLuint[?]", #elements, elements)
end

function M.BufferData(target, size, data, usage)
   ffi.C.glBufferData(target, size, data, usage)
end

M.EnableVertexAttribArray = ffi.C.glEnableVertexAttribArray
M.DisableVertexAttribArray = ffi.C.glDisableVertexAttribArray

function M.VertexAttribPointer(index, size, type, normalized, stride, pointer)
   ffi.C.glVertexAttribPointer(index, size, type, normalized, stride, ffi.cast("GLvoid *", pointer))
end

function M.UseProgram(program)
   ffi.C.glUseProgram(program.id)
end

M.Clear = ffi.C.glClear
M.DrawArrays = ffi.C.glDrawArrays

function M.DrawElements(mode, count, type, indices)
   ffi.C.glDrawElements(mode, count, type, ffi.cast("const GLvoid *", indices))
end

return setmetatable(M, { __index = ffi.C })
