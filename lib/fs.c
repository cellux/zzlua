#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <dirent.h>
#include <assert.h>

#include "msgpack.h"

struct stat * zz_fs_Stat_new() {
  return malloc(sizeof(struct stat));
}

__dev_t     zz_fs_Stat_dev(struct stat * buf) { return buf->st_dev; }
__ino_t     zz_fs_Stat_ino(struct stat * buf) { return buf->st_ino; }
__mode_t    zz_fs_Stat_mode(struct stat *buf) { return buf->st_mode; }
__mode_t    zz_fs_Stat_type(struct stat *buf) { return buf->st_mode & S_IFMT; }
__mode_t    zz_fs_Stat_perms(struct stat *buf) { return buf->st_mode & ~S_IFMT; }
__nlink_t   zz_fs_Stat_nlink(struct stat *buf) { return buf->st_nlink; }
__uid_t     zz_fs_Stat_uid(struct stat *buf) { return buf->st_uid; }
__gid_t     zz_fs_Stat_gid(struct stat *buf) { return buf->st_gid; }
__dev_t     zz_fs_Stat_rdev(struct stat *buf) { return buf->st_rdev; }
__off_t     zz_fs_Stat_size(struct stat *buf) { return buf->st_size; }
__blksize_t zz_fs_Stat_blksize(struct stat *buf) { return buf->st_blksize; }
__blkcnt_t  zz_fs_Stat_blocks(struct stat *buf) { return buf->st_blocks; }

struct timespec * zz_fs_Stat_atime(struct stat *buf) { return &buf->st_atim; }
struct timespec * zz_fs_Stat_mtime(struct stat *buf) { return &buf->st_mtim; }
struct timespec * zz_fs_Stat_ctime(struct stat *buf) { return &buf->st_ctim; }

void zz_fs_Stat_free(struct stat * buf) {
  free(buf);
}

int zz_fs_stat(const char *pathname, struct stat *buf) {
  return stat(pathname, buf);
}

int zz_fs_lstat(const char *pathname, struct stat *buf) {
  return lstat(pathname, buf);
}

char * zz_fs_dirent_name(struct dirent *entry) {
  return entry->d_name;
}

const char * zz_fs_type(__mode_t mode) {
  if (S_ISREG(mode))
    return "reg";
  else if (S_ISDIR(mode))
    return "dir";
  else if (S_ISLNK(mode))
    return "lnk";
  else if (S_ISCHR(mode))
    return "chr";
  else if (S_ISBLK(mode))
    return "blk";
  else if (S_ISFIFO(mode))
    return "fifo";
  else if (S_ISSOCK(mode))
    return "sock";
  else
    return NULL;
}

enum {
  ZZ_ASYNC_FS_STAT,
  ZZ_ASYNC_FS_LSTAT
};

void zz_async_fs_stat(cmp_ctx_t *request, cmp_ctx_t *reply, int nargs) {
  char *pathname;
  struct stat *buf;
  assert(zz_cmp_read_ptr(request, (void**) &pathname));
  assert(zz_cmp_read_ptr(request, (void**) &buf));
  int rv = stat(pathname, buf);
  assert(cmp_write_sint(reply, rv));
}

void zz_async_fs_lstat(cmp_ctx_t *request, cmp_ctx_t *reply, int nargs) {
  char *pathname;
  struct stat *buf;
  assert(zz_cmp_read_ptr(request, (void**) &pathname));
  assert(zz_cmp_read_ptr(request, (void**) &buf));
  int rv = lstat(pathname, buf);
  assert(cmp_write_sint(reply, rv));
}

void *zz_async_fs_handlers[] = {
  zz_async_fs_stat,
  zz_async_fs_lstat,
  NULL
};
