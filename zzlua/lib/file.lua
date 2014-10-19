local ffi = require('ffi')
local sf = string.format

ffi.cdef [[

int open (const char *__file, int __oflag, ...);
ssize_t read (int __fd, void *__buf, size_t __nbytes);
int close (int __fd);

int access(const char *pathname, int mode);

__off_t lseek (int __fd, __off_t __offset, int __whence);

struct File_ct {
  int fd;
};
]]

local O_RDONLY = 0
local O_WRONLY = 1
local O_RDWR = 2

local SEEK_SET = 0
local SEEK_CUR = 1
local SEEK_END = 2

local F_OK = 0
local X_OK = 1
local W_OK = 2
local R_OK = 4

local File_mt = {}

function File_mt:read(rsize)
   if not rsize then
      local fpos = ffi.C.lseek(self.fd, 0, SEEK_CUR)
      local fsize = ffi.C.lseek(self.fd, 0, SEEK_END)
      rsize = fsize - fpos
      ffi.C.lseek(self.fd, fpos, SEEK_SET)
   end
   local buf = ffi.new("uint8_t[?]", rsize)
   local bytes_read = ffi.C.read(self.fd, buf, rsize)
   if bytes_read ~= rsize then
      error("read() failed")
   end
   return ffi.string(buf, rsize)
end

function File_mt:seek(offset, relative)
   if relative then
      return ffi.C.lseek(self.fd, offset, SEEK_CUR)
   elseif offset >= 0 then
      return ffi.C.lseek(self.fd, offset, SEEK_SET)
   else
      return ffi.C.lseek(self.fd, offset, SEEK_END)
   end
end

function File_mt:close()
   return ffi.C.close(self.fd)
end

File_mt.__index = File_mt
File_mt.__gc = File_mt.close

local File = ffi.metatype("struct File_ct", File_mt)

local M = {}

function M.open(path)
   local fd = ffi.C.open(path, O_RDONLY)
   return File(fd)
end

function M.read(path)
   local f = M.open(path)
   local contents = f:read()
   f:close()
   return contents
end

function M.exists(path)
   return ffi.C.access(path, F_OK) == 0
end

local M_mt = {
   __call = function(self, ...)
      return M.open(...)
   end
}

return setmetatable(M, M_mt)
