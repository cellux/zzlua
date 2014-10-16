#include <stdio.h>

#include <jack/jack.h>
#include <jack/midiport.h>
#include <jack/ringbuffer.h>
#include <jack/statistics.h>

#include <stdbool.h> /* needed by cmp.h */
#include <string.h>  /* for strlen() */

#include "nn.h"   /* nanomsg */
#include "cmp.h"  /* msgpack */

#include "jack.h"
#include "buffer.h"

#define SCRATCH_SIZE 1024

/* I assume that Jack never runs two callbacks simultaneously,
   so a shared scratch area is not a problem (famous last words :-) */

static unsigned char scratch[SCRATCH_SIZE];

/* similarly with the cmp context */

static cmp_ctx_t* get_shared_cmp_ctx() {
  static cmp_ctx_t cmp_ctx;
  static buffer_t cmp_buf;
  buffer_init(&cmp_buf, scratch, 0, SCRATCH_SIZE, false);
  static cmp_buffer_state cmp_buf_state;
  cmp_buf_state.buffer = &cmp_buf;
  cmp_buf_state.pos = 0;
  cmp_init(&cmp_ctx, &cmp_buf_state, cmp_buffer_reader, cmp_buffer_writer);
  return &cmp_ctx;
}

/* send an event to the zzlua scheduler */

static bool send_event(const char *msg_type, int socket, buffer_t *buffer) {
  if (buffer->size == buffer->capacity) {
    /* we handle this as an overflow */
    fprintf(stderr, "scratch overflow while serializing %s event!\n", msg_type);
    return false;
  }
  else {
    int bytes_sent = nn_send(socket,
                             buffer->data,
                             buffer->size,
                             0);
    if (bytes_sent != buffer->size) {
      fprintf(stderr, "nn_send() failed when sending %s event!\n", msg_type);
    }
    return bytes_sent == buffer->size;
  }
}

int zz_jack_process_callback (jack_nframes_t nframes, void *arg) {
  struct zz_jack_params *params = (struct zz_jack_params *) arg;

  /* midi send */

  int nbytes = jack_ringbuffer_read_space(params->midi_rb);
  if (nbytes > 0) {
    if (nbytes > SCRATCH_SIZE) {
      fprintf(stderr, "ringbuffer data doesn't fit into scratch area!\n");
      jack_ringbuffer_reset(params->midi_rb);
    }
    else {
      size_t bytes_read = jack_ringbuffer_read(params->midi_rb,
                                               (char*) scratch,
                                               nbytes);
      if (bytes_read != nbytes) {
        fprintf(stderr, "jack_ringbuffer_read() failed!\n");
      }
      else {
        /* process midi messages (send them out) */
        /* WARNING: this code cannot handle ZZ_PORTS_MAX > 32 */
        uint32_t port_initialized = 0;
        void *port_buffers[ZZ_PORTS_MAX];
        int i = 0;
        while (i < bytes_read) {
          unsigned char port_index = scratch[i++];
          if (port_index >= ZZ_PORTS_MAX) {
            fprintf(stderr, "midi out is not supported for ports with index >= %d\n", ZZ_PORTS_MAX);
          }
          else if (port_index >= params->nports) {
            fprintf(stderr, "invalid port_index: %d, must be < %d\n", port_index, params->nports);
          }
          else {
            uint32_t port_mask = 1 << port_index;
            if ( (port_initialized & port_mask) == 0) {
              jack_port_t *port = params->ports[port_index];
              port_buffers[port_index] = jack_port_get_buffer(port, nframes);
              jack_midi_clear_buffer(port_buffers[port_index]);
              port_initialized |= port_mask;
            }
            unsigned char data_size = scratch[i++];
            int rv = jack_midi_event_write(port_buffers[port_index], 0, &scratch[i], data_size);
            if (rv != 0) {
              fprintf(stderr, "jack_midi_event_write() failed\n");
            }
            i += data_size;
          }
        }
      }
    }
  }

  /* midi recv */

  jack_midi_event_t midi_event;

  int i, j, k;
  for (i = 0; i < params->nports; i++) {
    if ( (params->port_types[i] != ZZ_JACK_PORT_MIDI) ||
         ((params->port_flags[i] & JackPortIsInput) == 0)) {
      continue;
    }
    jack_port_t *port = params->ports[i];
    void *port_buffer = jack_port_get_buffer(port, nframes);
    uint32_t nevents = jack_midi_get_event_count(port_buffer);
    for (j = 0; j < nevents; j++) {
      int rv = jack_midi_event_get(&midi_event, port_buffer, j);
      if (rv != 0) {
        fprintf(stderr, "jack_midi_event_get() failed!\n");
        break;
      }
      cmp_ctx_t *cmp_ctx = get_shared_cmp_ctx();
      cmp_write_array(cmp_ctx, 2);
      cmp_write_str(cmp_ctx, "jack.midi", 9);
      cmp_write_array(cmp_ctx, midi_event.size);
      for (k = 0; k < midi_event.size; k++) {
        cmp_write_u8(cmp_ctx, midi_event.buffer[k]);
      }
      if (!send_event("jack.midi",
                      params->event_socket,
                      ((cmp_buffer_state*)cmp_ctx->buf)->buffer)) {
        break;
      }
    }
  }
  return 0;
}

int zz_jack_xrun_callback(void *arg) {
  struct zz_jack_params *params = (struct zz_jack_params *) arg;
  float xrun_delayed_usecs = jack_get_xrun_delayed_usecs(params->client);
  cmp_ctx_t *cmp_ctx = get_shared_cmp_ctx();
  cmp_write_array(cmp_ctx, 2);
  cmp_write_str(cmp_ctx, "jack.xrun", 9);
  cmp_write_float(cmp_ctx, xrun_delayed_usecs);
  send_event("jack.xrun",
             params->event_socket,
             ((cmp_buffer_state*)cmp_ctx->buf)->buffer);
  return 0;
}

void zz_jack_info_shutdown_callback(jack_status_t code,
                                   const char *reason,
                                   void *arg) {
  struct zz_jack_params *params = (struct zz_jack_params *) arg;
  cmp_ctx_t *cmp_ctx = get_shared_cmp_ctx();
  cmp_write_array(cmp_ctx, 2);
  cmp_write_str(cmp_ctx, "jack.shutdown", 13);
  cmp_write_array(cmp_ctx, 2);
  cmp_write_sint(cmp_ctx, code);
  cmp_write_str(cmp_ctx, reason, strlen(reason));
  send_event("jack.shutdown",
             params->event_socket,
             ((cmp_buffer_state*)cmp_ctx->buf)->buffer);
}

int zz_jack_buffer_size_callback(jack_nframes_t nframes,
                                 void *arg) {
  struct zz_jack_params *params = (struct zz_jack_params *) arg;
  cmp_ctx_t *cmp_ctx = get_shared_cmp_ctx();
  cmp_write_array(cmp_ctx, 2);
  cmp_write_str(cmp_ctx, "jack.buffer-size", 16);
  cmp_write_uint(cmp_ctx, nframes);
  send_event("jack.buffer-size",
             params->event_socket,
             ((cmp_buffer_state*)cmp_ctx->buf)->buffer);
  return 0;
}

int zz_jack_sample_rate_callback(jack_nframes_t nframes,
                                 void *arg) {
  struct zz_jack_params *params = (struct zz_jack_params *) arg;
  cmp_ctx_t *cmp_ctx = get_shared_cmp_ctx();
  cmp_write_array(cmp_ctx, 2);
  cmp_write_str(cmp_ctx, "jack.sample-rate", 16);
  cmp_write_uint(cmp_ctx, nframes);
  send_event("jack.sample-rate",
             params->event_socket,
             ((cmp_buffer_state*)cmp_ctx->buf)->buffer);
  return 0;
}

void zz_jack_port_registration_callback(jack_port_id_t port,
                                        int reg,
                                        void *arg) {
  struct zz_jack_params *params = (struct zz_jack_params *) arg;
  cmp_ctx_t *cmp_ctx = get_shared_cmp_ctx();
  cmp_write_array(cmp_ctx, 2);
  cmp_write_str(cmp_ctx, "jack.port-registration", 22);
  cmp_write_array(cmp_ctx, 2);
  cmp_write_uint(cmp_ctx, port);
  cmp_write_sint(cmp_ctx, reg);
  send_event("jack.port-registration",
             params->event_socket,
             ((cmp_buffer_state*)cmp_ctx->buf)->buffer);
}

void zz_jack_client_registration_callback(const char* name,
                                          int reg,
                                          void *arg) {
  struct zz_jack_params *params = (struct zz_jack_params *) arg;
  cmp_ctx_t *cmp_ctx = get_shared_cmp_ctx();
  cmp_write_array(cmp_ctx, 2);
  cmp_write_str(cmp_ctx, "jack.client-registration", 24);
  cmp_write_array(cmp_ctx, 2);
  cmp_write_str(cmp_ctx, name, strlen(name));
  cmp_write_sint(cmp_ctx, reg);
  send_event("jack.client-registration",
             params->event_socket,
             ((cmp_buffer_state*)cmp_ctx->buf)->buffer);
}

void zz_jack_port_connect_callback(jack_port_id_t a,
                                   jack_port_id_t b,
                                   int connect,
                                   void *arg) {
  struct zz_jack_params *params = (struct zz_jack_params *) arg;
  cmp_ctx_t *cmp_ctx = get_shared_cmp_ctx();
  cmp_write_array(cmp_ctx, 2);
  cmp_write_str(cmp_ctx, "jack.port-connect", 17);
  cmp_write_array(cmp_ctx, 3);
  cmp_write_uint(cmp_ctx, a);
  cmp_write_uint(cmp_ctx, b);
  cmp_write_sint(cmp_ctx, connect);
  send_event("jack.port-connect",
             params->event_socket,
             ((cmp_buffer_state*)cmp_ctx->buf)->buffer);
}

void zz_jack_port_rename_callback(jack_port_id_t port,
                                  const char* old_name,
                                  const char* new_name,
                                  void *arg) {
  struct zz_jack_params *params = (struct zz_jack_params *) arg;
  cmp_ctx_t *cmp_ctx = get_shared_cmp_ctx();
  cmp_write_array(cmp_ctx, 2);
  cmp_write_str(cmp_ctx, "jack.port-rename", 16);
  cmp_write_array(cmp_ctx, 3);
  cmp_write_uint(cmp_ctx, port);
  cmp_write_str(cmp_ctx, old_name, strlen(old_name));
  cmp_write_str(cmp_ctx, new_name, strlen(new_name));
  send_event("jack.port-rename",
             params->event_socket,
             ((cmp_buffer_state*)cmp_ctx->buf)->buffer);
}
