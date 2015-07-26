local ffi = require('ffi')
local async = require('async')
local time = require('time') -- for struct timespec
local env = require('env')
local sys = require('sys')
local util = require('util')
local sf = string.format

ffi.cdef [[

enum {
  O_RDONLY = 0,
  O_WRONLY = 1,
  O_RDWR = 2
};

int     open (const char *__file, int __oflag, ...);
ssize_t read (int __fd, void *__buf, size_t __nbytes);
ssize_t write (int __fd, const void *__buf, size_t __n);
__off_t lseek (int __fd, __off_t __offset, int __whence);
int     close (int __fd);

int     access (const char *pathname, int mode);
int     chmod (const char *__file, __mode_t __mode);
int     unlink (const char *filename);
int     rmdir (const char *filename);

int     dup (int old);
int     dup2 (int old, int new);

struct Stat_ct {
  struct stat *buf;
};

struct stat *     zz_file_Stat_new();
__dev_t           zz_file_Stat_dev(struct stat *);
__ino_t           zz_file_Stat_ino(struct stat *);
__mode_t          zz_file_Stat_mode(struct stat *);
__mode_t          zz_file_Stat_type(struct stat *buf);
__mode_t          zz_file_Stat_perms(struct stat *buf);
__nlink_t         zz_file_Stat_nlink(struct stat *);
__uid_t           zz_file_Stat_uid(struct stat *);
__gid_t           zz_file_Stat_gid(struct stat *);
__dev_t           zz_file_Stat_rdev(struct stat *);
__off_t           zz_file_Stat_size(struct stat *);
__blksize_t       zz_file_Stat_blksize(struct stat *);
__blkcnt_t        zz_file_Stat_blocks(struct stat *);
struct timespec * zz_file_Stat_atime(struct stat *);
struct timespec * zz_file_Stat_mtime(struct stat *);
struct timespec * zz_file_Stat_ctime(struct stat *);
void              zz_file_Stat_free(struct stat *);

int zz_file_stat(const char *pathname, struct stat *buf);
int zz_file_lstat(const char *pathname, struct stat *buf);

struct File_ct {
  int fd;
};

typedef struct __dirstream DIR;

struct Dir_ct {
  DIR *dir;
};

DIR *opendir(const char *path);
struct dirent * readdir (DIR *dir);
int closedir (DIR *dir);

char * zz_file_dirent_name(struct dirent *);

const char * zz_file_type(__mode_t mode);

/* creation of temporary files/directories */

int mkstemp (char *template);
char *mkdtemp (char *template);

/* async worker */

enum {
  ZZ_ASYNC_FILE_STAT = 1,
  ZZ_ASYNC_FILE_LSTAT,
  ZZ_ASYNC_FILE_LSEEK,
  ZZ_ASYNC_FILE_READ,
  ZZ_ASYNC_FILE_WRITE,
  ZZ_ASYNC_FILE_CLOSE
};

void zz_file_worker(int handler_id, cmp_ctx_t *request, cmp_ctx_t *reply, int nargs);

]]

local M = {}

local SEEK_SET = 0
local SEEK_CUR = 1
local SEEK_END = 2

local F_OK = 0
local X_OK = 1
local W_OK = 2
local R_OK = 4

-- file

local ASYNC_FILE  = async.register_worker(ffi.C.zz_file_worker)

local File_mt = {}

local function lseek(fd, offset, whence)
   local rv
   if coroutine.running() then
      rv = async.request(ASYNC_FILE, ffi.C.ZZ_ASYNC_FILE_LSEEK, fd, offset, whence)
   else
      rv = ffi.C.lseek(fd, offset, whence)
   end
   return util.check_bad("lseek", -1, rv)
end

function File_mt:pos()
   return lseek(self.fd, 0, SEEK_CUR)
end

function File_mt:size()
   local pos = self:pos()
   local size = lseek(self.fd, 0, SEEK_END)
   lseek(self.fd, pos, SEEK_SET)
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
   if bytes_read ~= rsize then
      error(sf("read() failed: expected to read %d bytes, got %d bytes", rsize, bytes_read))
   end
   return ffi.string(buf, rsize)
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
      return lseek(self.fd, offset, SEEK_CUR)
   elseif offset >= 0 then
      return lseek(self.fd, offset, SEEK_SET)
   else
      return lseek(self.fd, offset, SEEK_END)
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

local File = ffi.metatype("struct File_ct", File_mt)

-- stat

local Stat_mt = {}

function Stat_mt:stat(path)
   if coroutine.running() then
      return async.request(ASYNC_FILE,
                           ffi.C.ZZ_ASYNC_FILE_STAT,
                           ffi.cast("size_t", ffi.cast("char*", path)),
                           ffi.cast("size_t", ffi.cast("struct stat*", self.buf)))
   else
      return ffi.C.zz_file_stat(path, self.buf)
   end
end

function Stat_mt:lstat(path)
   if coroutine.running() then
      return async.request(ASYNC_FILE,
                           ffi.C.ZZ_ASYNC_FILE_LSTAT,
                           ffi.cast("size_t", ffi.cast("char*", path)),
                           ffi.cast("size_t", ffi.cast("struct stat*", self.buf)))
   else
      return ffi.C.zz_file_lstat(path, self.buf)
   end
end

local Stat_accessors = {
   dev = function(buf)
      return tonumber(ffi.C.zz_file_Stat_dev(buf))
   end,
   ino = function(buf)
      return tonumber(ffi.C.zz_file_Stat_ino(buf))
   end,
   mode = function(buf)
      return tonumber(ffi.C.zz_file_Stat_mode(buf))
   end,
   perms = function(buf)
      return tonumber(ffi.C.zz_file_Stat_perms(buf))
   end,
   type = function(buf)
      return tonumber(ffi.C.zz_file_Stat_type(buf))
   end,
   nlink = function(buf)
      return tonumber(ffi.C.zz_file_Stat_nlink(buf))
   end,
   uid = function(buf)
      return tonumber(ffi.C.zz_file_Stat_uid(buf))
   end,
   gid = function(buf)
      return tonumber(ffi.C.zz_file_Stat_gid(buf))
   end,
   rdev = function(buf)
      return tonumber(ffi.C.zz_file_Stat_rdev(buf))
   end,
   size = function(buf)
      return tonumber(ffi.C.zz_file_Stat_size(buf))
   end,
   blksize = function(buf)
      return tonumber(ffi.C.zz_file_Stat_blksize(buf))
   end,
   blocks = function(buf)
      return tonumber(ffi.C.zz_file_Stat_blocks(buf))
   end,
   atime = function(buf)
      return tonumber(ffi.C.zz_file_Stat_atime(buf).tv_sec)
   end,
   mtime = function(buf)
      return tonumber(ffi.C.zz_file_Stat_mtime(buf).tv_sec)
   end,
   ctime = function(buf)
      return tonumber(ffi.C.zz_file_Stat_ctime(buf).tv_sec)
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

function Stat_mt:free()
   if self.buf ~= nil then
      ffi.C.zz_file_Stat_free(self.buf)
      self.buf = nil
   end
end

Stat_mt.__gc = Stat_mt.free

local Stat = ffi.metatype("struct Stat_ct", Stat_mt)

local Dir_mt = {}

function Dir_mt:read()
   local entry = ffi.C.readdir(self.dir)
   if entry ~= nil then
      return ffi.string(ffi.C.zz_file_dirent_name(entry))
   else
      return nil
   end
end

function Dir_mt:close()
   if self.dir ~= nil then
      util.check_ok("closedir", 0, ffi.C.closedir(self.dir))
      self.dir = nil
   end
   return 0
end

Dir_mt.__index = Dir_mt
Dir_mt.__gc = Dir_mt.close

local Dir = ffi.metatype("struct Dir_ct", Dir_mt)

function M.open(path)
   local fd = ffi.C.open(path, ffi.C.O_RDONLY)
   return File(fd)
end

function M.read(path)
   local f = M.open(path)
   local contents = f:read()
   f:close()
   return contents
end

function M.opendir(path)
   return Dir(util.check_bad("opendir", nil, ffi.C.opendir(path)))
end

function M.readdir(path)
   local dir = M.opendir(path)
   local function next()
      local entry = dir:read()
      if not entry then
         dir:close()
      end
      return entry
   end
   return next
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
   local s = Stat(ffi.C.zz_file_Stat_new())
   if s:stat(path)==0 then
      return s
   else
      return nil
   end
end

function M.lstat(path)
   local s = Stat(ffi.C.zz_file_Stat_new())
   if s:lstat(path)==0 then
      return s
   else
      return nil
   end
end

function M.type(path)
   local s = M.lstat(path)
   return s and ffi.string(ffi.C.zz_file_type(s.mode))
end

local function create_type_checker(typ)
   M["is_"..typ] = function(path)
      return M.type(path)==typ
   end
end

create_type_checker("reg")
create_type_checker("dir")
create_type_checker("lnk")
create_type_checker("chr")
create_type_checker("blk")
create_type_checker("fifo")
create_type_checker("sock")

function M.chmod(path, mode)
   return util.check_bad("chmod", -1, ffi.C.chmod(path, mode))
end

function M.unlink(path)
   return util.check_bad("unlink", -1, ffi.C.unlink(path))
end

function M.rmdir(path)
   return util.check_bad("rmdir", -1, ffi.C.rmdir(path))
end

function M.mkstemp(filename_prefix, tmpdir)
   filename_prefix = filename_prefix or sf("%u", sys.getpid())
   tmpdir = tmpdir or env.TMPDIR or '/tmp'
   local template = sf("%s/%s-XXXXXX", tmpdir, filename_prefix)
   local buf = ffi.new("char[?]", #template+1)
   ffi.copy(buf, template)
   local fd = util.check_bad("mkstemp", -1, ffi.C.mkstemp(buf))
   local self = {
      fd = fd,
      path = ffi.string(buf)
   }
   return setmetatable(self, File_mt)
end

local M_mt = {
   __index = ffi.C,
   __call = function(self, ...)
      return M.open(...)
   end
}

return setmetatable(M, M_mt)
