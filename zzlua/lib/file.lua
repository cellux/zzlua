local ffi = require('ffi')
local sf = string.format

ffi.cdef [[

int     open (const char *__file, int __oflag, ...);
ssize_t read (int __fd, void *__buf, size_t __nbytes);
int     close (int __fd);
int     access (const char *pathname, int mode);
__off_t lseek (int __fd, __off_t __offset, int __whence);
int     chmod (const char *__file, __mode_t __mode);

struct Stat_ct {
  struct stat *buf;
};

struct stat *     zzlua_Stat_new();
__dev_t           zzlua_Stat_dev(struct stat *);
__ino_t           zzlua_Stat_ino(struct stat *);
__mode_t          zzlua_Stat_mode(struct stat *);
__mode_t          zzlua_Stat_type(struct stat *buf);
__mode_t          zzlua_Stat_perms(struct stat *buf);
__nlink_t         zzlua_Stat_nlink(struct stat *);
__uid_t           zzlua_Stat_uid(struct stat *);
__gid_t           zzlua_Stat_gid(struct stat *);
__dev_t           zzlua_Stat_rdev(struct stat *);
__off_t           zzlua_Stat_size(struct stat *);
__blksize_t       zzlua_Stat_blksize(struct stat *);
__blkcnt_t        zzlua_Stat_blocks(struct stat *);
struct timespec * zzlua_Stat_atime(struct stat *);
struct timespec * zzlua_Stat_mtime(struct stat *);
struct timespec * zzlua_Stat_ctime(struct stat *);
void              zzlua_Stat_free(struct stat *);

void zzlua_stat(const char *pathname, struct stat *buf);
void zzlua_lstat(const char *pathname, struct stat *buf);

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

local Stat_mt = {}

function Stat_mt:stat(path)
   return ffi.C.zzlua_stat(path, self.buf)
end

function Stat_mt:lstat(path)
   return ffi.C.zzlua_lstat(path, self.buf)
end

local Stat_accessors = {
   dev = function(buf)
      return tonumber(ffi.C.zzlua_Stat_dev(buf))
   end,
   ino = function(buf)
      return tonumber(ffi.C.zzlua_Stat_ino(buf))
   end,
   mode = function(buf)
      return tonumber(ffi.C.zzlua_Stat_mode(buf))
   end,
   perms = function(buf)
      return tonumber(ffi.C.zzlua_Stat_perms(buf))
   end,
   type = function(buf)
      return tonumber(ffi.C.zzlua_Stat_type(buf))
   end,
   nlink = function(buf)
      return tonumber(ffi.C.zzlua_Stat_nlink(buf))
   end,
   uid = function(buf)
      return tonumber(ffi.C.zzlua_Stat_uid(buf))
   end,
   gid = function(buf)
      return tonumber(ffi.C.zzlua_Stat_gid(buf))
   end,
   rdev = function(buf)
      return tonumber(ffi.C.zzlua_Stat_rdev(buf))
   end,
   size = function(buf)
      return tonumber(ffi.C.zzlua_Stat_size(buf))
   end,
   blksize = function(buf)
      return tonumber(ffi.C.zzlua_Stat_blksize(buf))
   end,
   blocks = function(buf)
      return tonumber(ffi.C.zzlua_Stat_blocks(buf))
   end,
   atime = function(buf)
      return tonumber(ffi.C.zzlua_Stat_atime(buf).tv_sec)
   end,
   mtime = function(buf)
      return tonumber(ffi.C.zzlua_Stat_mtime(buf).tv_sec)
   end,
   ctime = function(buf)
      return tonumber(ffi.C.zzlua_Stat_ctime(buf).tv_sec)
   end,
}

function Stat_mt:__index(key)
   local accessor = Stat_accessors[key]
   if accessor then
      return accessor(self.buf)
   else
      local field = rawget(Stat_mt, key)
      if field then
         return field
      else
         error(sf("invalid key: %s, no such field in struct stat", key))
      end
   end
end

function Stat_mt:__gc()
   ffi.C.zzlua_Stat_free(self.buf)
end

local Stat = ffi.metatype("struct Stat_ct", Stat_mt)

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

function M.is_readable(path)
   return ffi.C.access(path, R_OK) == 0
end

function M.is_writable(path)
   return ffi.C.access(path, W_OK) == 0
end

function M.is_executable(path)
   return ffi.C.access(path, X_OK) == 0
end

function M.stat(path)
   local s = Stat(ffi.C.zzlua_Stat_new())
   s:stat(path)
   return s
end

function M.lstat(path)
   local s = Stat(ffi.C.zzlua_Stat_new())
   s:lstat(path)
   return s
end

function M.chmod(path, mode)
   return ffi.C.chmod(path, mode)
end

local M_mt = {
   __call = function(self, ...)
      return M.open(...)
   end
}

return setmetatable(M, M_mt)
