#include <string.h>

#include "msgpack.h"

#define MIN(a,b) ((a) < (b) ? (a) : (b))

bool zz_cmp_buffer_reader(struct cmp_ctx_s *ctx, void *data, size_t limit) {
  zz_cmp_buffer_state *state = (zz_cmp_buffer_state*) ctx->buf;
  if (state->pos >= state->buffer->size) {
    return false;
  }
  size_t left_in_buf = state->buffer->size - state->pos;
  size_t bytes_to_read = MIN(left_in_buf, limit);
  memcpy(data, state->buffer->data + state->pos, bytes_to_read);
  state->pos += bytes_to_read;
  return bytes_to_read == limit;
}

size_t zz_cmp_buffer_writer(struct cmp_ctx_s *ctx, const void *data, size_t count) {
  zz_cmp_buffer_state *state = (zz_cmp_buffer_state*) ctx->buf;
  uint32_t bytes_appended = zz_buffer_append(state->buffer, data, count);
  state->pos += bytes_appended;
  /* cmp.c uses the return value as a bool so I guess it must be
     non-zero if all bytes could be written and 0 otherwise */
  return bytes_appended == count ? bytes_appended : 0;
}