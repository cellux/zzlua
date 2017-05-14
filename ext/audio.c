#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <SDL2/SDL_audio.h>

#include "audio.h"
#include "trigger.h"

#define MIN(x,y) (((x) < (y)) ? (x) : (y))

struct zz_audio_Mixer {
  struct zz_audio_Source *next; /* chain of sources to mix */
  float *buf; /* temp buffer for source samples */
};

void zz_audio_Mixer_cb (void *userdata, float *stream, int len) {
  struct zz_audio_Mixer *mixer = (struct zz_audio_Mixer *) userdata;
  memset(stream, 0, len);
  struct zz_audio_Source *source = mixer->next;
  while (source != NULL) {
    int channels = 2;
    int frames = len / (channels * sizeof(float));
    int filled = source->callback(source->userdata, mixer->buf, frames);
    if (filled) {
      int samples = frames * channels;
      for (int i=0; i<samples; i++) {
        stream[i] += mixer->buf[i];
      }
    }
    source = source->next;
  }
}

struct zz_audio_Sample {
  struct zz_audio_Source src;
  float *buf; /* array of float samples */
  int frames;
  int channels;
  int pos;
  int playing; /* 1: playing, 0: paused */
  zz_trigger end_signal; /* triggered at end of sample */
};

int zz_audio_Sample_cb (void *userdata, float *stream, int frames) {
  struct zz_audio_Sample *sample = (struct zz_audio_Sample *) userdata;
  if (sample->pos < 0) sample->pos = 0;
  if (sample->pos > sample->frames) sample->pos = sample->frames;
  if (sample->playing != 0 && sample->pos == sample->frames) {
    sample->playing = 0;
  }
  if (sample->playing == 0) {
    return 0;
  }
  /* frame_count: how many sample frames to copy into stream */
  int frame_count = MIN(sample->frames - sample->pos, frames);
  /* zero_count: how many zero frames to copy into stream */
  int zero_count = frames - frame_count;
  float *src = sample->buf + sample->pos * sample->channels;
  float *dst = (float*) stream;
  switch (sample->channels) {
  case 2:
    memcpy(dst, src, 2 * frame_count * sizeof(float));
    src += 2 * frame_count;
    dst += 2 * frame_count;
    break;
  case 1:
    for (int i=0; i<frame_count; i++) {
      float sample = *(src++);
      *(dst++) = sample;
      *(dst++) = sample;
    }
    break;
  default:
    fprintf(stderr, "unsupported number of sample channels: %d\n", sample->channels);
    exit(1);
  }
  if (zero_count > 0) {
    memset(dst, 0, 2 * zero_count * sizeof(float));
  }
  sample->pos += frame_count;
  if (sample->pos >= sample->frames) {
    zz_trigger_fire(&sample->end_signal);
  }
  return 1;
}
