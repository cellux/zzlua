local ffi = require('ffi')
local async = require('async')
local time = require('time') -- for struct timespec
local env = require('env')
local sys = require('sys')
local util = require('util')

ffi.cdef [[

enum {
  R_OK = 4,
  W_OK = 2,
  X_OK = 1,
  F_OK = 0
};

int     access (const char *pathname, int mode);
int     chmod (const char *__file, __mode_t __mode);
int     unlink (const char *filename);
int     rmdir (const char *filename);

int     dup (int old);
int     dup2 (int old, int new);

char   *dirname (char *path);
char   *basename (char *path);

struct zz_fs_Stat_ct {
  struct stat *buf;
};

struct stat *     zz_fs_Stat_new();
__dev_t           zz_fs_Stat_dev(struct stat *);
__ino_t           zz_fs_Stat_ino(struct stat *);
__mode_t          zz_fs_Stat_mode(struct stat *);
__mode_t          zz_fs_Stat_type(struct stat *buf);
__mode_t          zz_fs_Stat_perms(struct stat *buf);
__nlink_t         zz_fs_Stat_nlink(struct stat *);
__uid_t           zz_fs_Stat_uid(struct stat *);
__gid_t           zz_fs_Stat_gid(struct stat *);
__dev_t           zz_fs_Stat_rdev(struct stat *);
__off_t           zz_fs_Stat_size(struct stat *);
__blksize_t       zz_fs_Stat_blksize(struct stat *);
__blkcnt_t        zz_fs_Stat_blocks(struct stat *);
struct timespec * zz_fs_Stat_atime(struct stat *);
struct timespec * zz_fs_Stat_mtime(struct stat *);
struct timespec * zz_fs_Stat_ctime(struct stat *);
void              zz_fs_Stat_free(struct stat *);

int zz_fs_stat(const char *pathname, struct stat *buf);
int zz_fs_lstat(const char *pathname, struct stat *buf);

typedef struct __dirstream DIR;

struct zz_fs_Dir_ct {
  DIR *dir;
};

DIR *opendir(const char *path);
struct dirent * readdir (DIR *dir);
int closedir (DIR *dir);

char * zz_fs_dirent_name(struct dirent *);

const char * zz_fs_type(__mode_t mode);

/* async worker */

enum {
  ZZ_ASYNC_FS_STAT,
  ZZ_ASYNC_FS_LSTAT
};

void *zz_async_fs_handlers[];

]]

local M = {}

local ASYNC_FS  = async.register_worker(ffi.C.zz_async_fs_handlers)

-- stat

local Stat_mt = {}

function Stat_mt:stat(path)
   if coroutine.running() then
      return async.request(ASYNC_FS,
                           ffi.C.ZZ_ASYNC_FS_STAT,
                           ffi.cast("size_t", ffi.cast("char*", path)),
                           ffi.cast("size_t", ffi.cast("struct stat*", self.buf)))
   else
      return ffi.C.zz_fs_stat(path, self.buf)
   end
end

function Stat_mt:lstat(path)
   if coroutine.running() then
      return async.request(ASYNC_FS,
                           ffi.C.ZZ_ASYNC_FS_LSTAT,
                           ffi.cast("size_t", ffi.cast("char*", path)),
                           ffi.cast("size_t", ffi.cast("struct stat*", self.buf)))
   else
      return ffi.C.zz_fs_lstat(path, self.buf)
   end
end

local Stat_accessors = {
   dev = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_dev(buf))
   end,
   ino = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_ino(buf))
   end,
   mode = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_mode(buf))
   end,
   perms = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_perms(buf))
   end,
   type = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_type(buf))
   end,
   nlink = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_nlink(buf))
   end,
   uid = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_uid(buf))
   end,
   gid = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_gid(buf))
   end,
   rdev = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_rdev(buf))
   end,
   size = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_size(buf))
   end,
   blksize = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_blksize(buf))
   end,
   blocks = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_blocks(buf))
   end,
   atime = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_atime(buf).tv_sec)
   end,
   mtime = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_mtime(buf).tv_sec)
   end,
   ctime = function(buf)
      return tonumber(ffi.C.zz_fs_Stat_ctime(buf).tv_sec)
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
         ef("invalid key: %s, no such field in struct stat", key)
      end
   end
end

function Stat_mt:free()
   if self.buf ~= nil then
      ffi.C.zz_fs_Stat_free(self.buf)
      self.buf = nil
   end
end

Stat_mt.__gc = Stat_mt.free

local Stat = ffi.metatype("struct zz_fs_Stat_ct", Stat_mt)

local Dir_mt = {}

function Dir_mt:read()
   local entry = ffi.C.readdir(self.dir)
   if entry ~= nil then
      return ffi.string(ffi.C.zz_fs_dirent_name(entry))
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

local Dir = ffi.metatype("struct zz_fs_Dir_ct", Dir_mt)

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
   return ffi.C.access(path, ffi.C.F_OK) == 0
end

function M.is_readable(path)
   return ffi.C.access(path, ffi.C.R_OK) == 0
end

function M.is_writable(path)
   return ffi.C.access(path, ffi.C.W_OK) == 0
end

function M.is_executable(path)
   return ffi.C.access(path, ffi.C.X_OK) == 0
end

function M.stat(path)
   local s = Stat(ffi.C.zz_fs_Stat_new())
   if s:stat(path)==0 then
      return s
   else
      return nil
   end
end

function M.lstat(path)
   local s = Stat(ffi.C.zz_fs_Stat_new())
   if s:lstat(path)==0 then
      return s
   else
      return nil
   end
end

function M.type(path)
   local s = M.lstat(path)
   return s and ffi.string(ffi.C.zz_fs_type(s.mode))
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
   return util.check_errno("chmod", ffi.C.chmod(path, mode))
end

function M.unlink(path)
   return util.check_errno("unlink", ffi.C.unlink(path))
end

function M.rmdir(path)
   return util.check_errno("rmdir", ffi.C.rmdir(path))
end

function M.basename(path)
   -- may modify its argument, so let's make a copy
   local path_copy = ffi.new("char[?]", #path+1)
   ffi.copy(path_copy, path)
   return ffi.string(ffi.C.basename(path_copy))
end

function M.dirname(path)
   -- may modify its argument, so let's make a copy
   local path_copy = ffi.new("char[?]", #path+1)
   ffi.copy(path_copy, path)
   return ffi.string(ffi.C.dirname(path_copy))
end

local function join(path, ...)
   local n_rest = select('#', ...)
   if n_rest == 0 then
      return path
   elseif type(path)=="string" then
      return sf("%s/%s", path, join(...))
   else
      ef("Invalid argument to join: %s", path)
   end
end

M.join = join

return setmetatable(M, { __index = ffi.C })
