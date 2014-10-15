#include <stdio.h>

#include <jack/jack.h>
#include <jack/midiport.h>
#include <jack/ringbuffer.h>
#include <stdbool.h> /* for cmp */

#include "nn.h"   /* nanomsg */
#include "cmp.h"  /* msgpack */

#include "jack.h"
#include "buffer.h"

#define MIDI_BUF_SIZE 1024

int zz_jack_process_callback (jack_nframes_t nframes, void *arg) {
  static unsigned char midi_buf[MIDI_BUF_SIZE];
  struct zz_jack_params *params = (struct zz_jack_params *) arg;

  /* midi send */

  int nbytes = jack_ringbuffer_read_space(params->midi_rb);
  if (nbytes > 0) {
    if (nbytes > MIDI_BUF_SIZE) {
      fprintf(stderr, "MIDI_BUF_SIZE exceeded!\n");
      jack_ringbuffer_reset(params->midi_rb);
    }
    else {
      size_t bytes_read = jack_ringbuffer_read(params->midi_rb, midi_buf, nbytes);
      if (bytes_read != nbytes) {
        fprintf(stderr, "jack_ringbuffer_read() failed!\n");
      }
      else {
        /* process midi messages (send them out) */
        uint32_t port_initialized = 0;
        void *port_buffers[32];
        int i = 0;
        while (i < bytes_read) {
          unsigned char port_index = midi_buf[i++];
          if (port_index >= 32) {
            fprintf(stderr, "midi out is not supported for ports with index >= 32\n");
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
            unsigned char data_size = midi_buf[i++];
            int rv = jack_midi_event_write(port_buffers[port_index], 0, &midi_buf[i], data_size);
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
  cmp_ctx_t cmp_ctx;
  buffer_t *cmp_buf = buffer_new();
  buffer_cmp_state cmp_state = { cmp_buf, 0 };

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
      cmp_init(&cmp_ctx, &cmp_state, buffer_cmp_reader, buffer_cmp_writer);
      cmp_write_array(&cmp_ctx, 2);
      cmp_write_str(&cmp_ctx, "jack.midi", 9);
      cmp_write_array(&cmp_ctx, midi_event.size);
      for (k = 0; k < midi_event.size; k++) {
        cmp_write_u8(&cmp_ctx, midi_event.buffer[k]);
      }
      int bytes_sent = nn_send(params->event_socket, cmp_buf->data, cmp_buf->size, 0);
      if (bytes_sent != cmp_buf->size) {
        fprintf(stderr, "nn_send() failed\n");
        break;
      }
      /* reuse buffer for next round */
      cmp_buf->size = 0;
      cmp_state.pos = 0;
    }
  }
  free(cmp_buf);
  return 0;
}
