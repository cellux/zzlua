//
// buffer.h
//
// Copyright (c) 2012 TJ Holowaychuk <tj@vision-media.ca>
//

#ifndef BUFFER
#define BUFFER

#include <inttypes.h>

#ifndef BUFFER_DEFAULT_CAPACITY
#define BUFFER_DEFAULT_CAPACITY 256
#endif

typedef struct {
  uint32_t size;
  uint32_t capacity;
  uint8_t *data;
} buffer_t;

buffer_t * buffer_new();
buffer_t * buffer_new_with_capacity(uint32_t capacity);
buffer_t * buffer_new_with_data(void *data, uint32_t size);
buffer_t * buffer_new_with_string(char *str);
buffer_t * buffer_new_with_string_length(char *str, uint32_t size);

uint32_t buffer_size(buffer_t *self);
uint32_t buffer_capacity(buffer_t *self);
uint8_t * buffer_data(buffer_t *self);

buffer_t * buffer_resize(buffer_t *self, uint32_t n);
buffer_t * buffer_append(buffer_t *self, const void *data, uint32_t size);
int buffer_equals(buffer_t *self, buffer_t *other);
void buffer_fill(buffer_t *self, uint8_t c);
void buffer_clear(buffer_t *self);

void buffer_free(buffer_t *self);

#endif
