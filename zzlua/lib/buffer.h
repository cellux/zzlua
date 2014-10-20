#ifndef ZZ_BUFFER
#define ZZ_BUFFER

#include <inttypes.h>
#include <stdbool.h>

#ifndef ZZ_BUFFER_DEFAULT_CAPACITY
#define ZZ_BUFFER_DEFAULT_CAPACITY 256
#endif

typedef struct {
  uint8_t *data;
  uint32_t size;
  uint32_t capacity;
  int dynamic;
} zz_buffer_t;

void zz_buffer_init(zz_buffer_t *self,
                    uint8_t *data,
                    uint32_t size,
                    uint32_t capacity,
                    int dynamic);

zz_buffer_t * zz_buffer_new();
zz_buffer_t * zz_buffer_new_with_capacity(uint32_t capacity);
zz_buffer_t * zz_buffer_new_with_data(void *data, uint32_t size);

uint32_t zz_buffer_resize(zz_buffer_t *self, uint32_t n);
uint32_t zz_buffer_append(zz_buffer_t *self, const void *data, uint32_t size);

int zz_buffer_equals(zz_buffer_t *self, zz_buffer_t *other);

void zz_buffer_fill(zz_buffer_t *self, uint8_t c);
void zz_buffer_clear(zz_buffer_t *self);
void zz_buffer_reset(zz_buffer_t *self);

void zz_buffer_free(zz_buffer_t *self);

/* cmp-zz_buffer interop */

struct cmp_ctx_s;

typedef struct {
  zz_buffer_t *buffer;
  uint32_t pos;
} zz_cmp_buffer_state;

bool zz_cmp_buffer_reader(struct cmp_ctx_s *ctx, void *data, size_t limit);
size_t zz_cmp_buffer_writer(struct cmp_ctx_s *ctx, const void *data, size_t count);

#endif
