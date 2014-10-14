//
// buffer.c
//
// Copyright (c) 2012 TJ Holowaychuk <tj@vision-media.ca>
//

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <sys/types.h>
#include "buffer.h"

// TODO: shared with reference counting
// TODO: linked list for append/prepend etc

/*
 * Compute the nearest multiple of `a` from `b`.
 */

#define nearest_multiple_of(a, b) \
  (((b) + ((a) - 1)) & ~((a) - 1))

buffer_t * buffer_new() {
  return buffer_new_with_capacity(BUFFER_DEFAULT_CAPACITY);
}

buffer_t * buffer_new_with_capacity(uint32_t capacity) {
  buffer_t *self = malloc(sizeof(buffer_t));
  if (!self) return NULL;
  self->data = calloc(capacity, 1);
  if (!self->data) return NULL;
  self->capacity = capacity;
  self->size = 0;
  return self;
}

buffer_t * buffer_new_with_data(void *data, uint32_t size) {
  buffer_t *self = buffer_new_with_capacity(size);
  memcpy(self->data, data, size);
  self->size = size;
  return self;
}

buffer_t * buffer_new_with_string(char *str) {
  return buffer_new_with_string_length(str, strlen(str));
}

buffer_t * buffer_new_with_string_length(char *str, uint32_t size) {
  return buffer_new_with_data(str, size);
}

uint32_t buffer_size(buffer_t *self) {
  return self->size;
}

uint32_t buffer_capacity(buffer_t *self) {
  return self->capacity;
}

uint8_t * buffer_data(buffer_t *self) {
  return self->data;
}

buffer_t * buffer_resize(buffer_t *self, uint32_t n) {
  n = nearest_multiple_of(1024, n);
  self->data = realloc(self->data, n);
  if (!self->data) return NULL;
  self->capacity = n;
  if (self->capacity < self->size) {
    self->size = self->capacity;
  }
  return self;
}

buffer_t * buffer_append(buffer_t *self, const void *data, uint32_t size) {
  uint32_t new_size = self->size + size;
  if (new_size > self->capacity) {
    if (buffer_resize(self, new_size)==NULL) {
      return NULL;
    }
  }
  memcpy(self->data + self->size, data, size);
  self->size = new_size;
  return self;
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

void buffer_free(buffer_t *self) {
  free(self->data);
  free(self);
}
