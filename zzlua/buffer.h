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
  size_t size;
  size_t capacity;
  uint8_t *data;
} buffer_t;

buffer_t * buffer_new();
buffer_t * buffer_new_with_capacity(size_t capacity);
buffer_t * buffer_new_with_data(void *data, size_t size);
buffer_t * buffer_new_with_string(char *str);
buffer_t * buffer_new_with_string_length(char *str, size_t size);

size_t buffer_size(buffer_t *self);
size_t buffer_capacity(buffer_t *self);
uint8_t * buffer_data(buffer_t *self);

buffer_t * buffer_resize(buffer_t *self, size_t n);
buffer_t * buffer_append(buffer_t *self, const void *data, size_t size);
int buffer_equals(buffer_t *self, buffer_t *other);
void buffer_fill(buffer_t *self, uint8_t c);
void buffer_clear(buffer_t *self);

void buffer_free(buffer_t *self);

#endif
