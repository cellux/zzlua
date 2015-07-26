#include <stdlib.h>

int zz_sys_atexit(void (*fn)(void)) {
  return atexit(fn);
}
