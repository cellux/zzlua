local ffi = require('ffi')
local sf = string.format

ffi.cdef [[
typedef struct {
  uint8_t *data;
  uint32_t size;
  uint32_t capacity;
  bool dynamic;
} buffer_t;

void buffer_init(buffer_t *self,
                 uint8_t *data,
                 uint32_t size,
                 uint32_t capacity,
                 bool dynamic);

buffer_t * buffer_new();
buffer_t * buffer_new_with_capacity(uint32_t capacity);
buffer_t * buffer_new_with_data(void *data, uint32_t size);

uint32_t buffer_resize(buffer_t *self, uint32_t n);
uint32_t buffer_append(buffer_t *self, const void *data, uint32_t size);

int buffer_equals(buffer_t *self, buffer_t *other);

void buffer_fill(buffer_t *self, uint8_t c);
void buffer_clear(buffer_t *self);
void buffer_reset(buffer_t *self);

void buffer_free(buffer_t *self);

/* cmp-buffer interop */

struct cmp_ctx_s;

typedef struct {
  buffer_t *buffer;
  uint32_t pos;
} cmp_buffer_state;

bool cmp_buffer_reader(struct cmp_ctx_s *ctx, void *data, size_t limit);
size_t cmp_buffer_writer(struct cmp_ctx_s *ctx, const void *data, size_t count);

struct Buffer_ct {
  buffer_t * buf;
};
]]

local Buffer_mt = {}

function Buffer_mt:size()
   return self.buf.size
end

function Buffer_mt:capacity()
   return self.buf.capacity
end

function Buffer_mt:data(index, length)
   index = index or 0
   length = length or (self.buf.size - index)
   return ffi.string(self.buf.data+index, length)
end

function Buffer_mt:__index(i)
   if type(i) == "number" then
      return self:data(i, 1)
   else
      return rawget(Buffer_mt, i)
   end
end

function Buffer_mt:__newindex(index, data)
   assert(type(index)=="number")
   local data_size = #data
   assert(index+data_size <= self.buf.size)
   ffi.copy(self.buf.data+index, data, data_size)
end

function Buffer_mt:resize(n)
   return ffi.C.buffer_resize(self.buf, n)
end

function Buffer_mt:append(buf, size)
   return ffi.C.buffer_append(self.buf, ffi.cast("void*", buf), size or #buf)
end

function Buffer_mt.__eq(buf1, buf2)
   if type(buf1) == "string" then
      return buf1 == buf2:data()
   elseif type(buf2) == "string" then
      return buf1:data() == buf2
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

function Buffer_mt:reset()
   ffi.C.buffer_reset(self.buf)
end

function Buffer_mt:free()
   ffi.C.buffer_free(self.buf)
end

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
      return Buffer(ffi.C.buffer_new_with_data(ffi.cast('void*', data), size))
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
