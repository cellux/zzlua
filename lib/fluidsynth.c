#include <stdio.h>
#include <stdint.h>
#include <fluidsynth.h>

#include "audio.h"

struct zz_fluidsynth_audio_source {
  struct zz_audio_Source src;
};

int zz_fluidsynth_audio_callback(void *userdata,
                                  float *stream,
                                  int frames)
{
  fluid_synth_t *synth = (fluid_synth_t*) userdata;
  /* [lr]{off,incr} args are offsets into float[] */
  fluid_synth_write_float(synth, frames,
                          stream, 0, 2,
                          stream, 1, 2);
  return 1;
}
