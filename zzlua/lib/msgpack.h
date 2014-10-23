#ifndef ZZ_MSGPACK_H
#define ZZ_MSGPACK_H

#include <stdbool.h>

#include "buffer.h"
#include "cmp.h"

typedef struct {
  zz_buffer_t *buffer;
  uint32_t pos;
} zz_cmp_buffer_state;

#define zz_cmp_ctx_state(ctx) ((zz_cmp_buffer_state*)((ctx)->buf))
#define zz_cmp_ctx_buffer(ctx) ((zz_cmp_ctx_state(ctx))->buffer)
#define zz_cmp_ctx_pos(ctx) ((zz_cmp_ctx_state(ctx))->pos)
#define zz_cmp_ctx_size(ctx) (zz_cmp_ctx_buffer(ctx)->size)
#define zz_cmp_ctx_data(ctx) (zz_cmp_ctx_buffer(ctx)->data)

bool zz_cmp_buffer_reader(struct cmp_ctx_s *ctx, void *data, size_t limit);
size_t zz_cmp_buffer_writer(struct cmp_ctx_s *ctx, const void *data, size_t count);

#endif
