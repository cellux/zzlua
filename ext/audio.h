typedef int (*zz_audio_cb) (void *userdata,
                            float *stream,
                            int frames);

/* struct zz_audio_Source
 * 
 * this structure shall be embedded as the first member of every
 * struct which holds data for an audio source
 *
 * the audio callback is invoked with stream pointing to a buffer of
 * float samples (nchannels=2). the callback shall store 2*frames
 * floating point values, each between [-1,1]. if the source produces
 * samples (fills stream), it shall return 1. if it doesn't, it shall
 * return 0 (so that the mixer knows it has to skip this source).
 *
 * userdata is typically the user-defined struct which embeds
 * zz_audio_Source
 *
 * the next pointers are used to chain the list of audio sources in
 * the mixer */

struct zz_audio_Source {
  zz_audio_cb callback;
  void *userdata;
  struct zz_audio_Source *next;
};
