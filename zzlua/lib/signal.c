#include <stdio.h>
#include <stdlib.h>
#include <signal.h>

#include "nanomsg/nn.h"
#include "nanomsg/pubsub.h"

#include "buffer.h"
#include "msgpack.h"

void *zz_signal_handler_thread(void *arg) {
  sigset_t ss;
  siginfo_t siginfo;
  int signum;
  int event_socket;
  int endpoint_id;
  unsigned char msg_buf[32];
  cmp_ctx_t cmp_ctx;
  zz_buffer_t cmp_buf;
  zz_cmp_buffer_state cmp_buf_state;

  zz_buffer_init(&cmp_buf, msg_buf, 0, 32, 0);
  cmp_buf_state.buffer = &cmp_buf;
  cmp_init(&cmp_ctx, &cmp_buf_state, zz_cmp_buffer_reader, zz_cmp_buffer_writer);

  event_socket = nn_socket(AF_SP, NN_PUB);
  if (event_socket < 0) {
    fprintf(stderr, "Cannot create event socket in zz_signal_handler_thread(), nn_socket() failed\n");
    exit(1);
  }
  endpoint_id = nn_connect(event_socket, "inproc://events");
  if (endpoint_id < 0) {
    fprintf(stderr, "Cannot connect event socket to event queue, nn_connect() failed\n");
    exit(1);
  }

  sigfillset(&ss);

  for (;;) {
    signum = sigwaitinfo(&ss, &siginfo);
    if (signum < 0) {
      fprintf(stderr, "sigwait() failed\n");
      exit(1);
    }
    zz_buffer_reset(&cmp_buf);
    cmp_buf_state.pos = 0;
    cmp_write_array(&cmp_ctx, 2);
    cmp_write_str(&cmp_ctx, "signal", 6);
    cmp_write_array(&cmp_ctx, 2);
    cmp_write_sint(&cmp_ctx, signum);
    cmp_write_sint(&cmp_ctx, siginfo.si_pid);
    int bytes_sent = nn_send(event_socket,
                             cmp_buf.data,
                             cmp_buf.size,
                             0);
    if (bytes_sent != cmp_buf.size) {
      fprintf(stderr, "nn_send() failed when sending signal event!\n");
    }
    if (signum == SIGTERM || signum == SIGINT) {
      break;
    }
  }
  return NULL;
}
