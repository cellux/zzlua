#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>

#include "msgpack.h"
#include "nanomsg/nn.h"
#include "nanomsg/pair.h"
#include "nanomsg/pubsub.h"

typedef void (*zz_async_worker)(cmp_ctx_t *request,
                                cmp_ctx_t *reply,
                                int nargs);

#define MAX_REGISTERED_WORKERS 256

static zz_async_worker registered_workers[MAX_REGISTERED_WORKERS];
static int registered_worker_count = 0;

int zz_register_worker(zz_async_worker worker) {
  if (registered_worker_count == MAX_REGISTERED_WORKERS) {
    fprintf(stderr, "cannot register more workers, %d limit exceeded\n",
            MAX_REGISTERED_WORKERS);
    exit(1);
  }
  registered_workers[registered_worker_count++] = worker;
  return registered_worker_count;
}

void *zz_async_worker_thread(void *arg) {
  /* arg: the id of this thread on the Lua side */

  zz_buffer_t *req_buf = zz_buffer_new_with_capacity(64);
  cmp_ctx_t req_ctx;
  zz_cmp_buffer_state req_state = { req_buf, 0 };

  zz_buffer_t *rep_buf = zz_buffer_new_with_capacity(64);
  cmp_ctx_t rep_ctx;
  zz_cmp_buffer_state rep_state = { rep_buf, 0 };

  char sockaddr[20];
  uint32_t thread_no = (uint32_t) arg;
  snprintf(sockaddr, sizeof(sockaddr), "inproc://async_%04x", thread_no);

  /* we get requests (from async.request) on the req socket */
  int req_socket = nn_socket(AF_SP, NN_PAIR);
  if (req_socket < 0) {
    fprintf(stderr, "cannot create req_socket: nn_socket() failed\n");
    exit(1);
  }
  if (nn_bind(req_socket, sockaddr) < 0) {
    fprintf(stderr, "cannot bind req_socket: nn_bind() failed\n");
    exit(1);
  }

  /* we deliver replies (to the scheduler) through rep_socket */
  int rep_socket = nn_socket(AF_SP, NN_PUB);
  if (rep_socket < 0) {
    fprintf(stderr, "cannot create rep_socket in worker thread: nn_socket() failed\n");
    exit(1);
  }
  if (nn_connect(rep_socket, "inproc://events") < 0) {
    fprintf(stderr, "cannot connect to event queue from worker thread: nn_connect() failed\n");
    exit(1);
  }

  /* we process requests until we get an exit signal, which is a
   * special request consisting of an array with zero elements */
  int nbytes;
  while (1) {
    nbytes = nn_recv(req_socket, req_buf->data, req_buf->capacity, 0);
    if (nbytes < 0) {
      fprintf(stderr, "nn_recv() failed\n");
      exit(1);
    }
    if (nbytes == req_buf->capacity) {
      // we treat this as overflow
      fprintf(stderr, "req_buf overflow\n");
      exit(1);
    }

    /* set up req for reading */
    cmp_init(&req_ctx, &req_state, zz_cmp_buffer_reader, zz_cmp_buffer_writer);
    req_buf->size = nbytes;
    req_state.pos = 0;

    /* set up rep for writing */
    cmp_init(&rep_ctx, &rep_state, zz_cmp_buffer_reader, zz_cmp_buffer_writer);
    zz_buffer_reset(rep_buf);
    rep_state.pos = 0;

    /* the request must be an array */
    uint32_t elements;
    if (! cmp_read_array(&req_ctx, &elements)) {
      fprintf(stderr, "invalid async request: not an array\n");
      exit(1);
    }
    if (elements == 0) {
      /* exit signal */
      break;
    }
    if (elements < 2) {
      fprintf(stderr, "invalid async request: should be an array of at least two elements: {worker_id, msg_id, ...}\n");
      exit(1);
    }
    /* worker_id is an index to the registered_workers array */
    double worker_id_dbl;
    if (! cmp_read_double(&req_ctx, &worker_id_dbl)) {
      fprintf(stderr, "invalid async request: doesn't start with worker id\n");
      exit(1);
    }
    uint32_t worker_id = (uint32_t) worker_id_dbl;
    if (worker_id < 1 || worker_id > registered_worker_count) {
      fprintf(stderr, "invalid async request: worker_id is out of range (registered_worker_count=%d, worker_id=%d)\n", registered_worker_count, worker_id);
      exit(1);
    }
    /* worker_id is 1-based */
    zz_async_worker worker = registered_workers[worker_id-1];
    /* msg_id is a unique identifier (a negative int) for this request.
       
       we use this value as the evtype of the event we send back to
       the scheduler so that it can find the Lua thread to wake up */
    double msg_id_dbl;
    if (! cmp_read_double(&req_ctx, &msg_id_dbl)) {
      fprintf(stderr, "invalid async request: msg_id not found\n");
      exit(1);
    }
    int32_t msg_id = (int32_t) msg_id_dbl;
    if (msg_id >= 0) {
      fprintf(stderr, "invalid async request: msg_id (%d) should be a negative number\n", msg_id);
      exit(1);
    }
    /* reply is an array of two elements */
    cmp_write_array(&rep_ctx, 2);
    /* first element is the msg_id */
    cmp_write_sint(&rep_ctx, msg_id);
    /* the second element must be written by the worker */
    worker(&req_ctx, &rep_ctx, elements-2);
    if (rep_buf->size == rep_buf->capacity) {
      fprintf(stderr, "rep_buf overflow\n");
      exit(1);
    }
    /* send reply to the scheduler as an event */
    nbytes = nn_send(rep_socket, rep_buf->data, rep_buf->size, 0);
    if (nbytes != rep_buf->size) {
      fprintf(stderr, "error sending async notification to scheduler\n");
      exit(1);
    }
  }
  nn_close(rep_socket);
  nn_close(req_socket);
  zz_buffer_free(rep_buf);
  zz_buffer_free(req_buf);
  return NULL;
}

/* a pre-defined worker for testing purposes */

void zz_async_echo_worker(cmp_ctx_t *request, cmp_ctx_t *reply, int nargs) {
  /* (delay, ...)
     @return ... packed into an array after delay seconds
  */
  double delay;
  if (! cmp_read_double(request, &delay)) {
    fprintf(stderr, "zz_async_echo_worker: got non-double first arg for delay\n");
    exit(1);
  }
  double fractional_part, integer_part;
  fractional_part = modf(delay, &integer_part);
  struct timespec rqtp;
  rqtp.tv_sec = integer_part;
  rqtp.tv_nsec = fractional_part * 1e9;
  if (nanosleep(&rqtp, NULL) != 0) {
    fprintf(stderr, "zz_async_echo_worker: nanosleep() failed\n");
  }
  /* return the rest of the arguments packed into an array */
  cmp_write_array(reply, nargs-1);
  int i;
  cmp_object_t obj;
  for (i=1; i<nargs; i++) {
    if (cmp_read_object(request, &obj)) {
      switch (obj.type) {
      case CMP_TYPE_POSITIVE_FIXNUM:
      case CMP_TYPE_UINT8:
        cmp_write_u8(reply, obj.as.u8);
        break;
      case CMP_TYPE_UINT16:
        cmp_write_u16(reply, obj.as.u16);
        break;
      case CMP_TYPE_UINT32:
        cmp_write_u32(reply, obj.as.u32);
        break;
      case CMP_TYPE_UINT64:
        cmp_write_u64(reply, obj.as.u64);
        break;
      case CMP_TYPE_NEGATIVE_FIXNUM:
      case CMP_TYPE_SINT8:
        cmp_write_s8(reply, obj.as.s8);
        break;
      case CMP_TYPE_SINT16:
        cmp_write_s16(reply, obj.as.s16);
        break;
      case CMP_TYPE_SINT32:
        cmp_write_s32(reply, obj.as.s32);
        break;
      case CMP_TYPE_SINT64:
        cmp_write_s64(reply, obj.as.s64);
        break;
      case CMP_TYPE_NIL:
        cmp_write_nil(reply);
        break;
      case CMP_TYPE_BOOLEAN:
        cmp_write_bool(reply, obj.as.boolean);
        break;
      case CMP_TYPE_FLOAT:
        cmp_write_float(reply, obj.as.flt);
        break;
      case CMP_TYPE_DOUBLE:
        cmp_write_double(reply, obj.as.dbl);
        break;
      case CMP_TYPE_FIXSTR:
      case CMP_TYPE_STR8:
      case CMP_TYPE_STR16:
      case CMP_TYPE_STR32:
        cmp_write_str(reply,
                      (const char*) zz_cmp_ctx_data(request) + zz_cmp_ctx_pos(request),
                      obj.as.str_size);
        zz_cmp_ctx_pos(request) += obj.as.str_size;
        break;
      default:
        fprintf(stderr, "zz_async_echo_worker: unsupported argument type\n");
      }
    }
  }
}
