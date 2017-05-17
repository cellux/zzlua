#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <SDL2/SDL_audio.h>
#include <SDL2/SDL_mutex.h>

#include "audio.h"
#include "trigger.h"

#define MIN(x,y) (((x) < (y)) ? (x) : (y))

void zz_audio_Engine_cb(void *userdata, float *stream, int len) {
  struct zz_audio_Source *s = (struct zz_audio_Source *) userdata;
  int channels = 2;
  int frames = len / (channels * sizeof(float));
  int filled = s->callback(s->userdata, stream, frames);
  if (!filled) {
    memset(stream, 0, len);
  }
}

struct zz_audio_Mixer {
  struct zz_audio_Source src;
  SDL_mutex *mutex;
  float *buf; /* temp buffer for source samples */
};

int zz_audio_Mixer_cb (void *userdata, float *stream, int frames) {
  struct zz_audio_Mixer *mixer = (struct zz_audio_Mixer *) userdata;
  struct zz_audio_Source *src = (struct zz_audio_Source *) userdata;
  if (!src->next) return 0;
  int channels = 2;
  int len = frames * channels * sizeof(float);
  memset(stream, 0, len);
  if (SDL_LockMutex(mixer->mutex) != 0) {
    fprintf(stderr, "zz_audio_Mixer_cb: SDL_LockMutex() failed\n");
    exit(1);
  }
  struct zz_audio_Source *s = src->next;
  while (s != NULL) {
    int filled = s->callback(s->userdata, mixer->buf, frames);
    if (filled) {
      int samples = frames * channels;
      for (int i=0; i<samples; i++) {
        stream[i] += mixer->buf[i];
      }
    }
    s = s->next;
  }
  if (SDL_UnlockMutex(mixer->mutex) != 0) {
    fprintf(stderr, "zz_audio_Mixer_cb: SDL_UnlockMutex() failed\n");
    exit(1);
  }
  return 1;
}

struct zz_audio_SamplePlayer {
  struct zz_audio_Source src;
  float *buf; /* array of float samples */
  int frames;
  int channels;
  int pos;
  int playing; /* 1: playing, 0: paused */
  zz_trigger end_signal; /* triggered at end of sample */
};

int zz_audio_SamplePlayer_cb (void *userdata, float *stream, int frames) {
  struct zz_audio_SamplePlayer *player = (struct zz_audio_SamplePlayer *) userdata;
  if (player->pos < 0) player->pos = 0;
  if (player->pos > player->frames) player->pos = player->frames;
  if (player->playing != 0 && player->pos == player->frames) {
    player->playing = 0;
  }
  if (player->playing == 0) {
    return 0;
  }
  /* frame_count: how many sample frames to copy into stream */
  int frame_count = MIN(player->frames - player->pos, frames);
  /* zero_count: how many zero frames to copy into stream */
  int zero_count = frames - frame_count;
  float *src = player->buf + player->pos * player->channels;
  float *dst = (float*) stream;
  switch (player->channels) {
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
    fprintf(stderr, "unsupported number of sample channels: %d\n", player->channels);
    exit(1);
  }
  if (zero_count > 0) {
    memset(dst, 0, 2 * zero_count * sizeof(float));
  }
  player->pos += frame_count;
  if (player->pos >= player->frames) {
    zz_trigger_fire(&player->end_signal);
  }
  return 1;
}
