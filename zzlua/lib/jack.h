#ifndef ZZ_JACK_H
#define ZZ_JACK_H

#define ZZ_JACK_PORT_AUDIO 1
#define ZZ_JACK_PORT_MIDI  2

#define ZZ_PORTS_MAX       32

struct zz_jack_params {
  jack_client_t *client;
  jack_ringbuffer_t *midi_rb;
  jack_port_t* ports[ZZ_PORTS_MAX];
  int port_types[ZZ_PORTS_MAX];
  int port_flags[ZZ_PORTS_MAX];
  int nports;
  int event_socket;
};

int zz_jack_process_callback (jack_nframes_t nframes, void *arg);

#endif
