#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "cmp.h"
#include "cmp_buffer.h"

#define MIN(a,b) ((a) < (b) ? (a) : (b))

bool buffer_cmp_reader(struct cmp_ctx_s *ctx, void *data, size_t limit) {
  buffer_cmp_state *state = (buffer_cmp_state*) ctx->buf;
  if (state->pos >= state->buffer->size) {
    return false;
  }
  size_t left_in_buf = state->buffer->size - state->pos;
  size_t bytes_to_read = MIN(left_in_buf, limit);
  memcpy(data, state->buffer->data + state->pos, bytes_to_read);
  state->pos += bytes_to_read;
  return bytes_to_read == limit;
}

size_t buffer_cmp_writer(struct cmp_ctx_s *ctx, const void *data, size_t count) {
  buffer_cmp_state *state = (buffer_cmp_state*) ctx->buf;
  if (buffer_append(state->buffer, data, count) == NULL) {
    return 0;
  }
  else {
    state->pos = state->buffer->size;
    return count;
  }
}
