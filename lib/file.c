#include <stdlib.h>
#include <unistd.h>
#include <assert.h>

#include "msgpack.h"

enum {
  ZZ_ASYNC_FILE_LSEEK,
  ZZ_ASYNC_FILE_READ,
  ZZ_ASYNC_FILE_WRITE,
  ZZ_ASYNC_FILE_CLOSE
};

void zz_async_file_lseek(cmp_ctx_t *request, cmp_ctx_t *reply, int nargs) {
  int fd;
  off_t offset;
  int whence;
  assert(zz_cmp_read_int(request, &fd));
  assert(zz_cmp_read_ssize_t(request, (ssize_t*) &offset));
  assert(zz_cmp_read_int(request, &whence));
  off_t rv = lseek(fd, offset, whence);
  assert(zz_cmp_write_size_t(reply, rv));
}

void zz_async_file_read(cmp_ctx_t *request, cmp_ctx_t *reply, int nargs) {
  int fd;
  void *buf;
  size_t count;
  assert(zz_cmp_read_int(request, &fd));
  assert(zz_cmp_read_ptr(request, (void**) &buf));
  assert(zz_cmp_read_size_t(request, &count));
  ssize_t rv = read(fd, buf, count);
  assert(zz_cmp_write_ssize_t(reply, rv));
}

void zz_async_file_write(cmp_ctx_t *request, cmp_ctx_t *reply, int nargs) {
  int fd;
  void *buf;
  size_t n;
  assert(zz_cmp_read_int(request, &fd));
  assert(zz_cmp_read_ptr(request, (void**) &buf));
  assert(zz_cmp_read_size_t(request, &n));
  ssize_t rv = write(fd, buf, n);
  assert(zz_cmp_write_ssize_t(reply, rv));
}

void zz_async_file_close(cmp_ctx_t *request, cmp_ctx_t *reply, int nargs) {
  int fd;
  assert(zz_cmp_read_int(request, &fd));
  int rv = close(fd);
  assert(cmp_write_sint(reply, rv));
}

void *zz_async_file_handlers[] = {
  zz_async_file_lseek,
  zz_async_file_read,
  zz_async_file_write,
  zz_async_file_close,
  NULL
};
