#ifndef BUFFER
#define BUFFER

#include <inttypes.h>
#include <stdbool.h>

#ifndef BUFFER_DEFAULT_CAPACITY
#define BUFFER_DEFAULT_CAPACITY 256
#endif

typedef struct {
  uint8_t *data;
  uint32_t size;
  uint32_t capacity;
  bool dynamic;
} buffer_t;

void buffer_init(buffer_t *self,
                 uint8_t *data,
                 uint32_t size,
                 uint32_t capacity,
                 bool dynamic);

buffer_t * buffer_new();
buffer_t * buffer_new_with_capacity(uint32_t capacity);
buffer_t * buffer_new_with_data(void *data, uint32_t size);

uint32_t buffer_resize(buffer_t *self, uint32_t n);
uint32_t buffer_append(buffer_t *self, const void *data, uint32_t size);

int buffer_equals(buffer_t *self, buffer_t *other);

void buffer_fill(buffer_t *self, uint8_t c);
void buffer_clear(buffer_t *self);
void buffer_reset(buffer_t *self);

void buffer_free(buffer_t *self);

/* cmp-buffer interop */

struct cmp_ctx_s;

typedef struct {
  buffer_t *buffer;
  uint32_t pos;
} cmp_buffer_state;

bool cmp_buffer_reader(struct cmp_ctx_s *ctx, void *data, size_t limit);
size_t cmp_buffer_writer(struct cmp_ctx_s *ctx, const void *data, size_t count);

#endif
