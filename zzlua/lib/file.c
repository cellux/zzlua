#include <stdlib.h>
#include <sys/stat.h>
#include <dirent.h>

struct stat * zz_file_Stat_new() {
  return malloc(sizeof(struct stat));
}

__dev_t     zz_file_Stat_dev(struct stat * buf) { return buf->st_dev; }
__ino_t     zz_file_Stat_ino(struct stat * buf) { return buf->st_ino; }
__mode_t    zz_file_Stat_mode(struct stat *buf) { return buf->st_mode; }
__mode_t    zz_file_Stat_type(struct stat *buf) { return buf->st_mode & S_IFMT; }
__mode_t    zz_file_Stat_perms(struct stat *buf) { return buf->st_mode & ~S_IFMT; }
__nlink_t   zz_file_Stat_nlink(struct stat *buf) { return buf->st_nlink; }
__uid_t     zz_file_Stat_uid(struct stat *buf) { return buf->st_uid; }
__gid_t     zz_file_Stat_gid(struct stat *buf) { return buf->st_gid; }
__dev_t     zz_file_Stat_rdev(struct stat *buf) { return buf->st_rdev; }
__off_t     zz_file_Stat_size(struct stat *buf) { return buf->st_size; }
__blksize_t zz_file_Stat_blksize(struct stat *buf) { return buf->st_blksize; }
__blkcnt_t  zz_file_Stat_blocks(struct stat *buf) { return buf->st_blocks; }

struct timespec * zz_file_Stat_atime(struct stat *buf) { return &buf->st_atim; }
struct timespec * zz_file_Stat_mtime(struct stat *buf) { return &buf->st_mtim; }
struct timespec * zz_file_Stat_ctime(struct stat *buf) { return &buf->st_ctim; }

void zz_file_Stat_free(struct stat * buf) {
  free(buf);
}

int zz_file_stat(const char *pathname, struct stat *buf) {
  return stat(pathname, buf);
}

int zz_file_lstat(const char *pathname, struct stat *buf) {
  return lstat(pathname, buf);
}

char * zz_file_dirent_name(struct dirent *entry) {
  return entry->d_name;
}

const char * zz_file_type(__mode_t mode) {
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
