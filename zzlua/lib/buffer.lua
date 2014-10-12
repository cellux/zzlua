local ffi = require('ffi')

ffi.cdef [[
typedef struct {
  size_t size;
  size_t capacity;
  uint8_t *data;
} buffer_t;

buffer_t * buffer_new();
buffer_t * buffer_new_with_capacity(size_t capacity);
buffer_t * buffer_new_with_data(void *data, size_t size);
buffer_t * buffer_new_with_string(char *str);
buffer_t * buffer_new_with_string_length(char *str, size_t size);

size_t buffer_size(buffer_t *self);
size_t buffer_capacity(buffer_t *self);
uint8_t * buffer_data(buffer_t *self);

buffer_t * buffer_append(buffer_t *self, void *data, size_t size);
int buffer_equals(buffer_t *self, buffer_t *other);
void buffer_fill(buffer_t *self, uint8_t c);
void buffer_clear(buffer_t *self);

void buffer_free(buffer_t *self);

struct Buffer_ct {
  buffer_t * buf;
};
]]

local Buffer_mt = {}

function Buffer_mt:size()
   return ffi.C.buffer_size(self.buf)
end

function Buffer_mt:capacity()
   return ffi.C.buffer_capacity(self.buf)
end

function Buffer_mt:data()
   return ffi.C.buffer_data(self.buf)
end

function Buffer_mt:str()
   return ffi.string(ffi.C.buffer_data(self.buf), self:size())
end

function Buffer_mt:append(buf, size)
   return ffi.C.buffer_append(self.buf, ffi.cast("void*", buf), size or #buf)
end

function Buffer_mt.__eq(buf1, buf2)
   if type(buf1) == "string" then
      return buf1 == buf2:str()
   elseif type(buf2) == "string" then
      return buf1:str() == buf2
   else
      return ffi.C.buffer_equals(buf1.buf, buf2.buf) ~= 0
   end
end

function Buffer_mt:fill(c)
   ffi.C.buffer_fill(self.buf, c)
end

function Buffer_mt:clear()
   ffi.C.buffer_clear(self.buf)
end

function Buffer_mt:free()
   ffi.C.buffer_free(self.buf)
end

Buffer_mt.__index = Buffer_mt
Buffer_mt.__gc = Buffer_mt.free

local Buffer = ffi.metatype("struct Buffer_ct", Buffer_mt)

local M = {}

M.DEFAULT_CAPACITY = 256

function M.new(data, size)
   if type(data) == "number" then
      assert(size==nil)
      local n = data
      return Buffer(ffi.C.buffer_new_with_capacity(n))
   elseif type(data) == "string" then
      size = size or #data
      assert(type(size)=="number")
      return Buffer(ffi.C.buffer_new_with_string_length(ffi.cast('char*', data), size))
   else
      assert(data==nil)
      assert(size==nil)
      return Buffer(ffi.C.buffer_new())
   end
end

local M_mt = {}

function M_mt:__call(...)
   return M.new(...)
end

return setmetatable(M, M_mt)
