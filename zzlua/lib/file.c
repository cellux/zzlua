#include <stdlib.h>
#include <sys/stat.h>

struct stat * zzlua_Stat_new() {
  return malloc(sizeof(struct stat));
}

__dev_t zzlua_Stat_dev(struct stat * buf) { return buf->st_dev; }
__ino_t zzlua_Stat_ino(struct stat * buf) { return buf->st_ino; }
__mode_t zzlua_Stat_mode(struct stat *buf) { return buf->st_mode; }
__mode_t zzlua_Stat_type(struct stat *buf) { return buf->st_mode & S_IFMT; }
__mode_t zzlua_Stat_perms(struct stat *buf) { return buf->st_mode & ~S_IFMT; }
__nlink_t zzlua_Stat_nlink(struct stat *buf) { return buf->st_nlink; }
__uid_t zzlua_Stat_uid(struct stat *buf) { return buf->st_uid; }
__gid_t zzlua_Stat_gid(struct stat *buf) { return buf->st_gid; }
__dev_t zzlua_Stat_rdev(struct stat *buf) { return buf->st_rdev; }
__off_t zzlua_Stat_size(struct stat *buf) { return buf->st_size; }
__blksize_t zzlua_Stat_blksize(struct stat *buf) { return buf->st_blksize; }
__blkcnt_t zzlua_Stat_blocks(struct stat *buf) { return buf->st_blocks; }
struct timespec * zzlua_Stat_atime(struct stat *buf) { return &buf->st_atim; }
struct timespec * zzlua_Stat_mtime(struct stat *buf) { return &buf->st_mtim; }
struct timespec * zzlua_Stat_ctime(struct stat *buf) { return &buf->st_ctim; }

void zzlua_Stat_free(struct stat * buf) {
  free(buf);
}

int zzlua_stat(const char *pathname, struct stat *buf) {
  return stat(pathname, buf);
}

int zzlua_lstat(const char *pathname, struct stat *buf) {
  return lstat(pathname, buf);
}
