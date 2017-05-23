local ffi = require('ffi')
local util = require('util')
local sched = require('sched')
local buffer = require('buffer')
local mm = require('mm')

local M = {}

M.BUFFER_SIZE = 4096

local BaseStream = util.Class()

function BaseStream:eof()
   ef("to be implemented")
end

function BaseStream:read1(ptr, size)
   ef("to be implemented")
end

function BaseStream:read(n)
   local BUFFER_SIZE = M.BUFFER_SIZE
   local buf
   if not n then
      -- read any amount of bytes
      if self.read_buffer then
         buf = self.read_buffer
         self.read_buffer = nil
      else
         local ptr, block_size = sched.get_block(BUFFER_SIZE)
         local nbytes = self:read1(ptr, block_size)
         buf = buffer.dup(ptr, nbytes)
         buf:size(nbytes)
         sched.ret_block(ptr, block_size)
      end
   elseif n > 0 then
      -- read exactly N bytes or until EOF
      buf = buffer.new_with_size(n)
      local dst = buf:ptr()
      local bytes_left = n
      while not self:eof() and bytes_left > 0 do
         if self.read_buffer then
            if #self.read_buffer <= bytes_left then
               ffi.copy(dst, self.read_buffer:ptr(), #self.read_buffer)
               dst = dst + #self.read_buffer
               bytes_left = bytes_left - #self.read_buffer
               self.read_buffer = nil
            else
               ffi.copy(dst, self.read_buffer:ptr(), bytes_left)
               dst = dst + bytes_left
               self.read_buffer = buffer.dup(self.read_buffer:ptr()+bytes_left, #self.read_buffer-bytes_left)
               bytes_left = 0
            end
         else
            local nbytes = self:read1(dst, bytes_left)
            dst = dst + nbytes
            bytes_left = bytes_left - nbytes
         end
      end
   elseif n == 0 then
      -- read until EOF
      local buffers = {}
      local total_size = 0
      local ptr, block_size = sched.get_block(BUFFER_SIZE)
      while not self:eof() do
         local nbytes = self:read1(ptr, block_size)
         total_size = total_size + nbytes
         if nbytes == block_size then
            table.insert(buffers, buffer.dup(ptr, block_size))
         else
            buf = buffer.new(total_size)
            for i=1,#buffers do
               buf:append(buffers[i])
            end
            buf:append(ptr, nbytes)
         end
      end
      sched.ret_block(ptr, block_size)
   end
   return buf
end

ffi.cdef [[ void * memmem (const void *haystack, size_t haystack_len,
                           const void *needle, size_t needle_len); ]]

function BaseStream:read_until(str)
   local buf = buffer.new()
   while not self:eof() do
      local chunk = self:read()
      buf:append(chunk)
      local p = ffi.cast("uint8_t*", ffi.C.memmem(buf:ptr(), #buf, str, #str))
      if p ~= nil then
         local str_offset = p - ffi.cast("uint8_t*", buf:ptr())
         local next_offset = str_offset + #str
         if next_offset < #buf then
            assert(self.read_buffer==nil)
            self.read_buffer = buffer.dup(buf:ptr()+next_offset, #buf-next_offset)
         end
         return buffer.dup(buf:ptr(), str_offset)
      end
   end
   return buf
end

function BaseStream:readln()
   return self:read_until("\x0a")
end

function BaseStream:write1(ptr, size)
   ef("to be implemented")
end

function BaseStream:write(data)
   local size
   if buffer.is_buffer(data) then
      size = #data
      data = data:ptr()
   end
   size = size or #data
   local nbytes = self:write1(ffi.cast("void*", data), size)
   assert(nbytes==size)
end

function BaseStream:writeln(line)
   self:write(line)
   self:write("\x0a")
end

local MemoryStream = util.Class(BaseStream)

function MemoryStream:create()
   return {
      buffers = {}
   }
end

function MemoryStream:eof()
   return #self.buffers == 0 and not self.read_buffer
end

function MemoryStream:write1(ptr, size)
   table.insert(self.buffers, buffer.dup(ptr, size))
   return size
end

function MemoryStream:read1(ptr, size)
   local dst = ffi.cast("uint8_t*", ptr)
   local bytes_left = size
   while #self.buffers > 0 and bytes_left > 0 do
      local buf = self.buffers[1]
      local bufsize = #buf
      if bufsize > bytes_left then
         ffi.copy(dst, buf:ptr(), bytes_left)
         self.buffers[1] = buffer.dup(buf:ptr()+bytes_left, #buf-bytes_left)
         bytes_left = 0
      elseif bufsize <= bytes_left then
         ffi.copy(dst, buf:ptr(), bufsize)
         dst = dst + bufsize
         bytes_left = bytes_left - bufsize
         table.remove(self.buffers, 1)
      end
   end
   return size - bytes_left
end

local function make_stream(x)
   if not x then
      return MemoryStream()
   elseif type(x)=="table" and type(x.stream_impl)=="function" then
      local s = BaseStream()
      return x:stream_impl(s)
   else
      ef("cannot create stream of %s", x)
   end
end

local M_mt = {}

function M_mt:__call(...)
   return make_stream(...)
end

return setmetatable(M, M_mt)
