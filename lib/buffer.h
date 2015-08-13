#ifndef ZZ_BUFFER
#define ZZ_BUFFER

#include <inttypes.h>

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

#endif
