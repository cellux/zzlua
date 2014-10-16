#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#include "cmp.h"

#include "buffer.h"

#define nearest_multiple_of(a, b) \
  (((b) + ((a) - 1)) & ~((a) - 1))

void buffer_init(buffer_t *self,
                 uint8_t *data,
                 uint32_t size,
                 uint32_t capacity,
                 bool dynamic) {
  self->data = data;
  self->size = size;
  self->capacity = capacity;
  self->dynamic = dynamic;
}

buffer_t * buffer_new() {
  return buffer_new_with_capacity(BUFFER_DEFAULT_CAPACITY);
}

buffer_t * buffer_new_with_capacity(uint32_t capacity) {
  buffer_t *self = malloc(sizeof(buffer_t));
  if (!self) {
    return NULL;
  }
  uint8_t *data = calloc(capacity, 1);
  if (!data) {
    free(self);
    return NULL;
  }
  uint32_t size = 0;
  bool dynamic = true;
  buffer_init(self, data, size, capacity, dynamic);
  return self;
}

buffer_t * buffer_new_with_data(void *data, uint32_t size) {
  buffer_t *self = buffer_new_with_capacity(size);
  if (self) {
    memcpy(self->data, data, size);
    self->size = size;
  }
  return self;
}

uint32_t buffer_resize(buffer_t *self, uint32_t n) {
  if (!self->dynamic) return 0;
  n = nearest_multiple_of(1024, n);
  self->data = realloc(self->data, n);
  if (!self->data) return 0;
  self->capacity = n;
  if (self->capacity < self->size) {
    self->size = self->capacity;
  }
  return self->capacity;
}

uint32_t buffer_append(buffer_t *self, const void *data, uint32_t size) {
  uint32_t new_size = self->size + size;
  if (new_size > self->capacity) {
    if (!buffer_resize(self, new_size)) {
      return 0;
    }
  }
  memcpy(self->data + self->size, data, size);
  self->size = new_size;
  return size;
}

int buffer_equals(buffer_t *self, buffer_t *other) {
  return (self->size == other->size) &&
    (0 == memcmp(self->data, other->data, self->size));
}

void buffer_fill(buffer_t *self, uint8_t c) {
  memset(self->data, c, self->size);
}

void buffer_clear(buffer_t *self) {
  buffer_fill(self, 0);
}

void buffer_reset(buffer_t *self) {
  self->size = 0;
}

void buffer_free(buffer_t *self) {
  if (self->data) {
    free(self->data);
    self->data = NULL;
  }
  free(self);
  self = NULL;
}

/* cmp interoperability */

#define MIN(a,b) ((a) < (b) ? (a) : (b))

bool cmp_buffer_reader(struct cmp_ctx_s *ctx, void *data, size_t limit) {
  cmp_buffer_state *state = (cmp_buffer_state*) ctx->buf;
  if (state->pos >= state->buffer->size) {
    return false;
  }
  size_t left_in_buf = state->buffer->size - state->pos;
  size_t bytes_to_read = MIN(left_in_buf, limit);
  memcpy(data, state->buffer->data + state->pos, bytes_to_read);
  state->pos += bytes_to_read;
  return bytes_to_read == limit;
}

size_t cmp_buffer_writer(struct cmp_ctx_s *ctx, const void *data, size_t count) {
  cmp_buffer_state *state = (cmp_buffer_state*) ctx->buf;
  uint32_t bytes_appended = buffer_append(state->buffer, data, count);
  state->pos += bytes_appended;
  /* cmp.c uses the return value as a bool so I guess it must be
     non-zero if all bytes could be written and 0 otherwise */
  return bytes_appended == count ? bytes_appended : 0;
}
