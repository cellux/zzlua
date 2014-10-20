local ffi = require('ffi')
local sf = string.format

ffi.cdef [[

typedef struct {
  uint8_t *data;
  uint32_t size;
  uint32_t capacity;
  int dynamic;
} zz_buffer_t;

void zz_buffer_init(zz_buffer_t *self,
                    uint8_t *data,
                    uint32_t size,
                    uint32_t capacity,
                    int dynamic);

zz_buffer_t * zz_buffer_new();
zz_buffer_t * zz_buffer_new_with_capacity(uint32_t capacity);
zz_buffer_t * zz_buffer_new_with_data(void *data, uint32_t size);

uint32_t zz_buffer_resize(zz_buffer_t *self, uint32_t n);
uint32_t zz_buffer_append(zz_buffer_t *self, const void *data, uint32_t size);

int zz_buffer_equals(zz_buffer_t *self, zz_buffer_t *other);

void zz_buffer_fill(zz_buffer_t *self, uint8_t c);
void zz_buffer_clear(zz_buffer_t *self);
void zz_buffer_reset(zz_buffer_t *self);

void zz_buffer_free(zz_buffer_t *self);

struct Buffer_ct {
  zz_buffer_t * buf;
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
   return ffi.C.zz_buffer_resize(self.buf, n)
end

function Buffer_mt:append(buf, size)
   return ffi.C.zz_buffer_append(self.buf, ffi.cast("void*", buf), size or #buf)
end

function Buffer_mt.__eq(buf1, buf2)
   if type(buf1) == "string" then
      return buf1 == buf2:data()
   elseif type(buf2) == "string" then
      return buf1:data() == buf2
   else
      return ffi.C.zz_buffer_equals(buf1.buf, buf2.buf) ~= 0
   end
end

function Buffer_mt:fill(c)
   ffi.C.zz_buffer_fill(self.buf, c)
end

function Buffer_mt:clear()
   ffi.C.zz_buffer_clear(self.buf)
end

function Buffer_mt:reset()
   ffi.C.zz_buffer_reset(self.buf)
end

function Buffer_mt:free()
   if self.buf ~= nil then
      ffi.C.zz_buffer_free(self.buf)
      self.buf = nil
   end
end

Buffer_mt.__gc = Buffer_mt.free

local Buffer = ffi.metatype("struct Buffer_ct", Buffer_mt)

local M = {}

M.DEFAULT_CAPACITY = 256

function M.new(data, size)
   if type(data) == "number" then
      assert(size==nil)
      local n = data
      return Buffer(ffi.C.zz_buffer_new_with_capacity(n))
   elseif type(data) == "string" then
      size = size or #data
      assert(type(size)=="number")
      return Buffer(ffi.C.zz_buffer_new_with_data(ffi.cast('void*', data), size))
   else
      assert(data==nil)
      assert(size==nil)
      return Buffer(ffi.C.zz_buffer_new())
   end
end

local M_mt = {}

function M_mt:__call(...)
   return M.new(...)
end

return setmetatable(M, M_mt)
