local ffi = require('ffi')
local async = require('async')
local env = require('env')
local sys = require('sys')
local util = require('util')
local fs = require('fs')

ffi.cdef [[

enum {
  O_RDONLY = 0,
  O_WRONLY = 1,
  O_RDWR = 2
};

enum {
  SEEK_SET = 0,
  SEEK_CUR = 1,
  SEEK_END = 2
};

int     open (const char *__file, int __oflag, ...);
ssize_t read (int __fd, void *__buf, size_t __nbytes);
ssize_t write (int __fd, const void *__buf, size_t __n);
__off_t lseek (int __fd, __off_t __offset, int __whence);
int     close (int __fd);

struct zz_file_File_ct {
  int fd;
};

/* creation of temporary files/directories */

int mkstemp (char *template);
char *mkdtemp (char *template);

/* async worker */

enum {
  ZZ_ASYNC_FILE_LSEEK,
  ZZ_ASYNC_FILE_READ,
  ZZ_ASYNC_FILE_WRITE,
  ZZ_ASYNC_FILE_CLOSE
};

void *zz_async_file_handlers[];

]]

local M = {}

-- file

local ASYNC_FILE  = async.register_worker(ffi.C.zz_async_file_handlers)

local File_mt = {}

local function lseek(fd, offset, whence)
   local rv
   if coroutine.running() then
      rv = async.request(ASYNC_FILE, ffi.C.ZZ_ASYNC_FILE_LSEEK, fd, offset, whence)
   else
      rv = ffi.C.lseek(fd, offset, whence)
   end
   return util.check_errno("lseek", rv)
end

function File_mt:pos()
   return lseek(self.fd, 0, ffi.C.SEEK_CUR)
end

function File_mt:size()
   local pos = self:pos()
   local size = lseek(self.fd, 0, ffi.C.SEEK_END)
   lseek(self.fd, pos, ffi.C.SEEK_SET)
   return size
end

function File_mt:read(rsize)
   if not rsize then
      -- read the whole rest of the file
      rsize = self:size() - self:pos()
   end
   local buf = ffi.new("uint8_t[?]", rsize)
   local bytes_read
   if coroutine.running() then
      bytes_read = async.request(ASYNC_FILE,
                                 ffi.C.ZZ_ASYNC_FILE_READ,
                                 self.fd,
                                 ffi.cast("size_t", ffi.cast("void*", buf)),
                                 rsize)
   else
      bytes_read = ffi.C.read(self.fd, buf, rsize)
   end
   return ffi.string(buf, bytes_read)
end

function File_mt:write(data)
   if coroutine.running() then
      return async.request(ASYNC_FILE,
                           ffi.C.ZZ_ASYNC_FILE_WRITE,
                           self.fd,
                           ffi.cast("size_t", ffi.cast("void*", data)),
                           #data)
   else
      return util.check_ok("write", #data, ffi.C.write(self.fd, data, #data))
   end
end

function File_mt:seek(offset, relative)
   if relative then
      return lseek(self.fd, offset, ffi.C.SEEK_CUR)
   elseif offset >= 0 then
      return lseek(self.fd, offset, ffi.C.SEEK_SET)
   else
      return lseek(self.fd, offset, ffi.C.SEEK_END)
   end
end

function File_mt:close()
   if self.fd >= 0 then
      local rv
      if coroutine.running() then
         rv = async.request(ASYNC_FILE, ffi.C.ZZ_ASYNC_FILE_CLOSE, self.fd)
      else
         rv = ffi.C.close(self.fd)
      end
      util.check_ok("close", 0, rv)
      self.fd = -1
   end
   return 0
end

File_mt.__index = File_mt
File_mt.__gc = File_mt.close

local File = ffi.metatype("struct zz_file_File_ct", File_mt)

function M.open(path)
   local fd = util.check_errno("open", ffi.C.open(path, ffi.C.O_RDONLY))
   return File(fd)
end

function M.read(path, rsize)
   local f = M.open(path)
   local contents = f:read(rsize)
   f:close()
   return contents
end

function M.mkstemp(filename_prefix, tmpdir)
   filename_prefix = filename_prefix or sf("%u", sys.getpid())
   tmpdir = tmpdir or env.TMPDIR or '/tmp'
   local template = sf("%s/%s-XXXXXX", tmpdir, filename_prefix)
   local buf = ffi.new("char[?]", #template+1)
   ffi.copy(buf, template)
   local fd = util.check_errno("mkstemp", ffi.C.mkstemp(buf))
   return File(fd), ffi.string(buf)
end

function M.mktemp(...)
   local fd, path = M.mkstemp(...)
   fd:close()
   fs.unlink(path)
   return path
end

local M_mt = {
   __index = ffi.C,
   __call = function(self, ...)
      return M.open(...)
   end
}

return setmetatable(M, M_mt)
