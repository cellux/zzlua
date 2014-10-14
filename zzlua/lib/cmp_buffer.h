#ifndef CMP_BUFFER_H
#define CMP_BUFFER_H

#include <stdbool.h>

#include "buffer.h"

struct cmp_ctx_s;

typedef struct {
  buffer_t *buffer;
  uint32_t pos;
} buffer_cmp_state;

bool buffer_cmp_reader(struct cmp_ctx_s *ctx, void *data, size_t limit);
size_t buffer_cmp_writer(struct cmp_ctx_s *ctx, const void *data, size_t count);

#endif
