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

typedef void                   GLvoid;
typedef char                   GLchar;
typedef unsigned int           GLenum;
typedef unsigned char          GLboolean;
typedef unsigned int           GLbitfield;
typedef khronos_int8_t         GLbyte;
typedef short                  GLshort;
typedef int                    GLint;
typedef int                    GLsizei;
typedef khronos_uint8_t        GLubyte;
typedef unsigned short         GLhalf;
typedef unsigned short         GLushort;
typedef unsigned int           GLuint;
typedef uint64_t               GLuint64;
typedef int64_t                GLint64;
typedef khronos_float_t        GLfloat;
typedef khronos_float_t        GLclampf;
typedef double                 GLclampd;
typedef khronos_int32_t        GLfixed;

typedef ptrdiff_t              GLsizeiptr;
typedef ptrdiff_t              GLintptr;

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
  GL_2_BYTES        = 0x1407,
  GL_3_BYTES        = 0x1408,
  GL_4_BYTES        = 0x1409,
  GL_DOUBLE         = 0x140A,
  GL_HALF_FLOAT     = 0x140B,
  GL_FIXED          = 0x140C
};

enum {
  GL_ALPHA                  = 0x1906,
  GL_RGB                    = 0x1907,
  GL_RGBA                   = 0x1908,
  GL_RGBA8                  = 0x8058,
  GL_LUMINANCE              = 0x1909,
  GL_LUMINANCE_ALPHA        = 0x190A
};

enum {
  GL_UNSIGNED_SHORT_4_4_4_4 = 0x8033,
  GL_UNSIGNED_SHORT_5_5_5_1 = 0x8034,
  GL_UNSIGNED_SHORT_5_6_5   = 0x8363
};

/* Utility */

enum {
  GL_VENDOR     = 0x1F00,
  GL_RENDERER   = 0x1F01,
  GL_VERSION    = 0x1F02,
  GL_EXTENSIONS = 0x1F03
};

enum {
  GL_SHADING_LANGUAGE_VERSION = 0x8B8C
};

/* Parameters */

void glGetBooleanv (GLenum pname, GLboolean *data);
void glGetFloatv (GLenum pname, GLfloat *data);
void glGetIntegerv (GLenum pname, GLint *data);

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

const GLubyte * glGetString (GLenum name);

GLuint glCreateShader (GLenum type);
void glShaderSource (GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length);
void glShaderBinary (GLsizei count, const GLuint *shaders, GLenum binaryformat, const void *binary, GLsizei length);
void glCompileShader (GLuint shader);
void glReleaseShaderCompiler (void);
void glGetShaderiv (GLuint shader, GLenum pname, GLint *params);
void glGetShaderInfoLog (GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
void glDeleteShader (GLuint shader);

GLuint glCreateProgram (void);
void glAttachShader (GLuint program, GLuint shader);
void glBindAttribLocation (GLuint program, GLuint index, const GLchar *name);
void glBindFragDataLocation (GLuint program, GLuint color, const GLchar *name);
GLint glGetAttribLocation (GLuint program, const GLchar *name);
GLint glGetUniformLocation (GLuint program, const GLchar *name);
void glLinkProgram (GLuint program);
void glUseProgram (GLuint program);
void glGetProgramiv (GLuint program, GLenum pname, GLint *params);
void glGetProgramInfoLog (GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
void glDetachShader (GLuint program, GLuint shader);
void glDeleteProgram (GLuint program);

void glUniform1f (GLint location, GLfloat v0);
void glUniform1fv (GLint location, GLsizei count, const GLfloat *value);
void glUniform1i (GLint location, GLint v0);
void glUniform1iv (GLint location, GLsizei count, const GLint *value);
void glUniform2f (GLint location, GLfloat v0, GLfloat v1);
void glUniform2fv (GLint location, GLsizei count, const GLfloat *value);
void glUniform2i (GLint location, GLint v0, GLint v1);
void glUniform2iv (GLint location, GLsizei count, const GLint *value);
void glUniform3f (GLint location, GLfloat v0, GLfloat v1, GLfloat v2);
void glUniform3fv (GLint location, GLsizei count, const GLfloat *value);
void glUniform3i (GLint location, GLint v0, GLint v1, GLint v2);
void glUniform3iv (GLint location, GLsizei count, const GLint *value);
void glUniform4f (GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3);
void glUniform4fv (GLint location, GLsizei count, const GLfloat *value);
void glUniform4i (GLint location, GLint v0, GLint v1, GLint v2, GLint v3);
void glUniform4iv (GLint location, GLsizei count, const GLint *value);
void glUniformMatrix2fv (GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
void glUniformMatrix3fv (GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
void glUniformMatrix4fv (GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);

void glVertexAttrib1f (GLuint index, GLfloat x);
void glVertexAttrib1fv (GLuint index, const GLfloat *v);
void glVertexAttrib2f (GLuint index, GLfloat x, GLfloat y);
void glVertexAttrib2fv (GLuint index, const GLfloat *v);
void glVertexAttrib3f (GLuint index, GLfloat x, GLfloat y, GLfloat z);
void glVertexAttrib3fv (GLuint index, const GLfloat *v);
void glVertexAttrib4f (GLuint index, GLfloat x, GLfloat y, GLfloat z, GLfloat w);
void glVertexAttrib4fv (GLuint index, const GLfloat *v);

void glGenVertexArrays (GLsizei n, GLuint *arrays);
void glBindVertexArray (GLuint array);
void glEnableVertexAttribArray (GLuint index);
void glDisableVertexAttribArray (GLuint index);
void glVertexAttribPointer (GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer);
void glDeleteVertexArrays (GLsizei n, const GLuint *arrays);

void glGenBuffers (GLsizei n, GLuint *buffers);
void glBindBuffer (GLenum target, GLuint buffer);
void glBufferData (GLenum target, GLsizeiptr size, const void *data, GLenum usage);
void glBufferSubData (GLenum target, GLintptr offset, GLsizeiptr size, const void *data);
void glDeleteBuffers (GLsizei n, const GLuint *buffers);

enum {
  GL_TEXTURE_2D = 0x0DE1,
  GL_TEXTURE_MAG_FILTER = 0x2800,
  GL_TEXTURE_MIN_FILTER = 0x2801,
  GL_TEXTURE_WRAP_S     = 0x2802,
  GL_TEXTURE_WRAP_T     = 0x2803
};

enum {
  GL_TEXTURE0  = 0x84C0,
  GL_TEXTURE1  = 0x84C1,
  GL_TEXTURE2  = 0x84C2,
  GL_TEXTURE3  = 0x84C3,
  GL_TEXTURE4  = 0x84C4,
  GL_TEXTURE5  = 0x84C5,
  GL_TEXTURE6  = 0x84C6,
  GL_TEXTURE7  = 0x84C7,
  GL_TEXTURE8  = 0x84C8,
  GL_TEXTURE9  = 0x84C9,
  GL_TEXTURE10 = 0x84CA,
  GL_TEXTURE11 = 0x84CB,
  GL_TEXTURE12 = 0x84CC,
  GL_TEXTURE13 = 0x84CD,
  GL_TEXTURE14 = 0x84CE,
  GL_TEXTURE15 = 0x84CF,
  GL_TEXTURE16 = 0x84D0,
  GL_TEXTURE17 = 0x84D1,
  GL_TEXTURE18 = 0x84D2,
  GL_TEXTURE19 = 0x84D3,
  GL_TEXTURE20 = 0x84D4,
  GL_TEXTURE21 = 0x84D5,
  GL_TEXTURE22 = 0x84D6,
  GL_TEXTURE23 = 0x84D7,
  GL_TEXTURE24 = 0x84D8,
  GL_TEXTURE25 = 0x84D9,
  GL_TEXTURE26 = 0x84DA,
  GL_TEXTURE27 = 0x84DB,
  GL_TEXTURE28 = 0x84DC,
  GL_TEXTURE29 = 0x84DD,
  GL_TEXTURE30 = 0x84DE,
  GL_TEXTURE31 = 0x84DF
};

enum {
  GL_LINEAR = 0x2601,
  GL_CLAMP_TO_EDGE = 0x812F
};

void glGenTextures (GLsizei n, GLuint *textures);
void glBindTexture (GLenum target, GLuint texture);
void glTexParameterf (GLenum target, GLenum pname, GLfloat param);
void glTexParameterfv (GLenum target, GLenum pname, const GLfloat *params);
void glTexParameteri (GLenum target, GLenum pname, GLint param);
void glTexParameteriv (GLenum target, GLenum pname, const GLint *params);
void glTexImage2D (GLenum target, GLint level, GLint internalFormat,
                   GLsizei width, GLsizei height, GLint border,
                   GLenum format, GLenum type, const void *pixels);
void glTexSubImage2D (GLenum target, GLint level, GLint xoffset, GLint yoffset,
                      GLsizei width, GLsizei height,
                      GLenum format, GLenum type, const void *pixels);
void glCopyTexImage2D (GLenum target, GLint level, GLenum internalformat, GLint x, GLint y, GLsizei width, GLsizei height, GLint border);
void glCopyTexSubImage2D (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLint x, GLint y, GLsizei width, GLsizei height);
void glActiveTexture (GLenum texture);
void glDeleteTextures (GLsizei n, const GLuint *textures);

enum {
  GL_COLOR_BUFFER_BIT   = 0x00004000,
  GL_DEPTH_BUFFER_BIT   = 0x00000100,
  GL_STENCIL_BUFFER_BIT = 0x00000400
};

void glClear (GLbitfield mask);
void glClearColor (GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);

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

enum {
  GL_RENDERBUFFER = 0x8D41
};

void glGenRenderbuffers (GLsizei n, GLuint *renderbuffers);
void glBindRenderbuffer (GLenum target, GLuint renderbuffer);
void glRenderbufferStorage (GLenum target, GLenum internalformat, GLsizei width, GLsizei height);
void glDeleteRenderbuffers (GLsizei n, const GLuint *renderbuffers);

enum {
  GL_FRAMEBUFFER = 0x8D40,
  GL_FRAMEBUFFER_BINDING = 0x8CA6
};

enum {
  GL_COLOR_ATTACHMENT0  = 0x8CE0,
  GL_DEPTH_ATTACHMENT   = 0x8D00,
  GL_STENCIL_ATTACHMENT = 0x8D20
};

void glGenFramebuffers (GLsizei n, GLuint *framebuffers);
void glBindFramebuffer (GLenum target, GLuint framebuffer);
void glFramebufferRenderbuffer (GLenum target, GLenum attachment, GLenum renderbuffertarget, GLuint renderbuffer);
void glFramebufferTexture2D (GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level);
void glDeleteFramebuffers (GLsizei n, const GLuint *framebuffers);

void glViewport (GLint x, GLint y, GLsizei width, GLsizei height);

void glFlush (void);
void glFinish (void);

]]

local function gl_loaded()
   local function check_gl_version()
      ffi.C.glGetString(ffi.C.GL_VERSION)
   end
   return pcall(check_gl_version)
end

if not gl_loaded() then
   local function try_load(libname)
      ffi.load(libname, true)
   end
   local candidate_libs = {"GL", "GLESv2"}
   for _,libname in ipairs(candidate_libs) do
      if pcall(try_load, libname) then
         --pf("loaded: %s", libname)
         break
      end
   end
end

-- TODO: throw an error if we could not load GL?

local M = {}

function M.GetError()
   return ffi.C.glGetError()
end

function M.GetBoolean(pname)
   local data = ffi.new("GLboolean[1]")
   ffi.C.GetBooleanv(pname, data)
   return data[0]
end

function M.GetFloat(pname)
   local data = ffi.new("GLfloat[1]")
   ffi.C.GetFloatv(pname, data)
   return data[0]
end

function M.GetInteger(pname)
   local data = ffi.new("GLint[1]")
   ffi.C.GetIntegerv(pname, data)
   return data[0]
end

function M.GetString(name)
   local rv = util.check_bad("glGetString", nil, ffi.C.glGetString(name))
   return ffi.string(rv)
end

-- Shader

local Shader_mt = {}

function Shader_mt:ShaderSource(text)
   local str = ffi.new("GLchar*[1]", ffi.cast("GLchar*", text))
   local len = ffi.new("GLint[1]", #text)
   ffi.C.glShaderSource(self.id,
                        1,
                        ffi.cast("const GLchar * const *", str),
                        len)
end

function Shader_mt:CompileShader()
   ffi.C.glCompileShader(self.id)
   local status = ffi.new("GLint[1]")
   ffi.C.glGetShaderiv(self.id, ffi.C.GL_COMPILE_STATUS, status)
   if status[0] == ffi.C.GL_FALSE then
      ef("glCompileShader() failed: %s", self:GetShaderInfoLog())
   end
end

function Shader_mt:GetShaderInfoLog()
   local length = ffi.new("GLint[1]")
   ffi.C.glGetShaderiv(self.id, ffi.C.GL_INFO_LOG_LENGTH, length)
   local log = ffi.new("GLchar[?]", length[0])
   local log_len = ffi.new("GLsizei[1]")
   ffi.C.glGetShaderInfoLog(self.id, length[0], log_len, log)
   return ffi.string(log, log_len[0])
end

function Shader_mt:DeleteShader()
   if self.id then
      ffi.C.glDeleteShader(self.id)
      self.id = nil
   end
end

Shader_mt.__index = Shader_mt
Shader_mt.__gc = Shader_mt.DeleteShader
Shader_mt.delete = Shader_mt.DeleteShader

function M.CreateShader(type)
   local id = util.check_bad("glCreateShader", 0, ffi.C.glCreateShader(type))
   local shader = { type = type, id = id }
   return setmetatable(shader, Shader_mt)
end

-- Program

local Program_mt = {}

function Program_mt:AttachShader(shader)
   ffi.C.glAttachShader(self.id, shader.id)
   self.shaders:push(shader)
end

function Program_mt:DetachShader(shader)
   ffi.C.glDetachShader(self.id, shader.id)
   self.shaders:remove(shader)
end

function Program_mt:detach_all()
   for shader in self.shaders:itervalues() do
      ffi.C.glDetachShader(self.id, shader.id)
   end
   self.shaders:clear()
end

function Program_mt:BindAttribLocation(index, name)
   ffi.C.glBindAttribLocation(self.id, index, name)
end

function Program_mt:BindFragDataLocation(index, name)
   ffi.C.glBindFragDataLocation(self.id, index, name)
end

function Program_mt:GetUniformLocation(name)
   return util.check_bad("glGetUniformLocation", -1, ffi.C.glGetUniformLocation(self.id, name))
end

function Program_mt:LinkProgram()
   ffi.C.glLinkProgram(self.id)
   local status = ffi.new("GLint[1]")
   ffi.C.glGetProgramiv(self.id, ffi.C.GL_LINK_STATUS, status)
   if status[0] == ffi.C.GL_FALSE then
      ef("glLinkProgram() failed: %s", self:GetProgramInfoLog())
   end
end

function Program_mt:GetProgramInfoLog()
   local length = ffi.new("GLint[1]")
   ffi.C.glGetProgramiv(self.id, ffi.C.GL_INFO_LOG_LENGTH, length)
   local log = ffi.new("GLchar[?]", length[0])
   local log_len = ffi.new("GLsizei[1]")
   ffi.C.glGetProgramInfoLog(self.id, length[0], log_len, log)
   return ffi.string(log, log_len[0])
end

function Program_mt:DeleteProgram()
   if self.id then
      ffi.C.glDeleteProgram(self.id)
      self.id = nil
   end
end

Program_mt.__index = Program_mt
Program_mt.__gc = Program_mt.DeleteProgram
Program_mt.delete = Program_mt.DeleteProgram

function M.CreateProgram()
   local id = util.check_bad("glCreateProgram", 0, ffi.C.glCreateProgram())
   local program = { id = id, shaders = adt.List() }
   return setmetatable(program, Program_mt)
end

-- VertexArray (VAO)

local VAO_mt = {}

function VAO_mt:DeleteVertexArray()
   if self.id then
      local arrays = ffi.new("GLuint[1]", self.id)
      ffi.C.glDeleteVertexArrays(1, arrays)
      self.id = nil
   end
end

VAO_mt.__index = VAO_mt
VAO_mt.__gc = VAO_mt.DeleteVertexArray
VAO_mt.delete = VAO_mt.DeleteVertexArray

function M.VAO()
   local arrays = ffi.new("GLuint[1]")
   ffi.C.glGenVertexArrays(1, arrays)
   local vao = { id = arrays[0] }
   return setmetatable(vao, VAO_mt)
end

function M.BindVertexArray(array)
   ffi.C.glBindVertexArray(array and array.id or 0)
end

M.VertexArray = M.VAO

-- VertexBuffer (VBO)

local VBO_mt = {}

function VBO_mt:DeleteBuffer()
   if self.id then
      local buffers = ffi.new("GLuint[1]", self.id)
      ffi.C.glDeleteBuffers(1, buffers)
      self.id = nil
   end
end

VBO_mt.__index = VBO_mt
VBO_mt.__gc = VBO_mt.DeleteBuffer
VBO_mt.delete = VBO_mt.DeleteBuffer

function M.VBO()
   local buffers = ffi.new("GLuint[1]")
   ffi.C.glGenBuffers(1, buffers)
   local vbo = { id = buffers[0] }
   return setmetatable(vbo, VBO_mt)
end

function M.BindBuffer(target, buffer)
   ffi.C.glBindBuffer(target, buffer.id)
end

M.Buffer = M.VBO

function M.FloatArray(elements)
   return ffi.new("GLfloat[?]", #elements, elements)
end

function M.UIntArray(elements)
   return ffi.new("GLuint[?]", #elements, elements)
end

function M.BufferData(target, size, data, usage)
   ffi.C.glBufferData(target, size, data, usage)
end

function M.EnableVertexAttribArray(index)
   ffi.C.glEnableVertexAttribArray(index)
end

function M.DisableVertexAttribArray(index)
   ffi.C.glDisableVertexAttribArray(index)
end

function M.VertexAttribPointer(index, size, type, normalized, stride, pointer)
   ffi.C.glVertexAttribPointer(index, size, type, normalized, stride, ffi.cast("GLvoid *", pointer))
end

-- Texture

local Texture_mt = {}

function Texture_mt:DeleteTexture()
   if self.id then
      local textures = ffi.new("GLuint[1]", self.id)
      ffi.C.glDeleteTextures(1, textures)
      self.id = nil
   end
end

Texture_mt.__index = Texture_mt
Texture_mt.__gc = Texture_mt.DeleteTexture
Texture_mt.delete = Texture_mt.DeleteTexture

function M.Texture()
   local textures = ffi.new("GLuint[1]")
   ffi.C.glGenTextures(1, textures)
   local texture = { id = textures[0] }
   return setmetatable(texture, Texture_mt)
end

function M.BindTexture(target, texture)
   ffi.C.glBindTexture(target, texture.id)
end

function M.TexParameteri(target, pname, param)
   ffi.C.glTexParameteri(target, pname, param)
end

function M.TexImage2D(target, level, internalFormat,
                      width, height, border,
                      format, type, pixels)
   ffi.C.glTexImage2D(target, level, internalFormat,
                      width, height, border,
                      format, type, ffi.cast("const void *", pixels))
end

function M.ActiveTexture(texture)
   ffi.C.glActiveTexture(texture)
end

function M.Uniform1i(location, v0)
   ffi.C.glUniform1i(location, v0)
end

function M.Flush()
   ffi.C.glFlush()
end

function M.Finish()
   ffi.C.glFinish()
end

--

function M.UseProgram(program)
   ffi.C.glUseProgram(program.id)
end

function M.Clear(mask)
   ffi.C.glClear(mask)
end

function M.DrawArrays(mode, first, count)
   ffi.C.glDrawArrays(mode, first, count)
end

function M.DrawElements(mode, count, type, indices)
   ffi.C.glDrawElements(mode, count, type, ffi.cast("const GLvoid *", indices))
end

local ResourceManager_mt = {}

function ResourceManager_mt:CreateShader(...)
   local shader = M.CreateShader(...)
   table.insert(self.shaders, shader)
   return shader
end

function ResourceManager_mt:CreateProgram(...)
   local program = M.CreateProgram(...)
   table.insert(self.programs, program)
   return program
end

function ResourceManager_mt:VAO(...)
   local vao = M.VAO(...)
   table.insert(self.vaos, vao)
   return vao
end

ResourceManager_mt.VertexArray = ResourceManager_mt.VAO

function ResourceManager_mt:VBO(...)
   local vbo = M.VBO(...)
   table.insert(self.vbos, vbo)
   return vbo
end

ResourceManager_mt.Buffer = ResourceManager_mt.VBO

function ResourceManager_mt:Texture(...)
   local texture = M.Texture(...)
   table.insert(self.textures, texture)
   return texture
end

function ResourceManager_mt:delete()
   for _,texture in ipairs(self.textures) do texture:delete() end
   self.textures = {}
   for _,vao in ipairs(self.vaos) do vao:delete() end
   self.vaos = {}
   for _,vbo in ipairs(self.vbos) do vbo:delete() end
   self.vbos = {}
   for _,program in ipairs(self.programs) do program:detach_all() end
   for _,shader in ipairs(self.shaders) do shader:delete() end
   self.shaders = {}
   for _,program in ipairs(self.programs) do program:delete() end
   self.programs = {}
end

ResourceManager_mt.__index = ResourceManager_mt
ResourceManager_mt.__gc = ResourceManager_mt.delete

function M.ResourceManager()
   local self = {
      shaders = {},
      programs = {},
      vaos = {},
      vbos = {},
      textures = {},
   }
   return setmetatable(self, ResourceManager_mt)
end

return setmetatable(M, { __index = ffi.C })
