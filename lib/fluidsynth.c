#include <stdio.h>
#include <stdint.h>
#include <fluidsynth.h>

void zz_fluidsynth_sdl_audio_callback(void *userdata,
                                      uint8_t *stream,
                                      int len)
{
  fluid_synth_t *synth = (fluid_synth_t*) userdata;
  int nchannels = 2;
  int sample_size = sizeof(int16_t);
  int frame_size = nchannels * sample_size;
  int nframes = len / frame_size;
  /* [lr]{off,incr} args are offsets into int16_t[] */
  fluid_synth_write_s16(synth, nframes,
                        stream, 0, 2,
                        stream, 1, 2);
}
