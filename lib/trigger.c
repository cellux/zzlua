#include <stdio.h>
#include <stdint.h>
#include <unistd.h>

#include "trigger.h"

void zz_trigger_fire(struct zz_trigger *t) {
  uint64_t data = 1;
  int nbytes = write(t->fd, &data, sizeof(uint64_t));
  if (nbytes != 8) {
    fprintf(stderr, "zz_trigger_fire() failed: cannot write to event fd\n");
    exit(1);
  }
}
