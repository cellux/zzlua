#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <pthread.h>
#include <assert.h>

#include <zmq.h>
#include <jack/jack.h>
#include <lauxlib.h>

/*** app state ***/

typedef struct {
  const char *client_name;
  
  /* signals */
  pthread_t signal_handler_thread;
  sigset_t old_sigset;

  /* 0MQ */
  void *zmq_ctx;
  void *zmq_sig_server_socket;
  void *zmq_sig_client_socket;
  void *zmq_jack_server_socket;
  void *zmq_jack_client_socket;

  /* lua */
  lua_State *L;

  /* jack */
  jack_client_t *jack_client;
} showtime_app_t;

/*** various helpers ***/

#define LOG(...) do {                                               \
    fprintf(stdout, __VA_ARGS__);                                   \
    fprintf(stdout, "\n");                                          \
  } while(0)

#define DIE(...) do {                                               \
    fprintf(stderr, "Error in %s line #%d:\n", __FILE__, __LINE__); \
    LOG(__VA_ARGS__);                                               \
    exit(1);                                                        \
  } while(0)

#define CHECK(expr, ...) if (!(expr)) DIE(__VA_ARGS__)

static void showtime_usage() {
  printf("Usage: showtime <client-name>\n");
  exit(0);
}

/*** messages ***/

typedef enum {
  /* signals */
  SHOWTIME_SIGNAL_RECEIVED,
  /* jack */
  SHOWTIME_JACK_PORT_REGISTRATION,
  SHOWTIME_JACK_CLIENT_REGISTRATION
} showtime_msg_type;

#define SHOWTIME_MAX_CLIENT_NAME_LENGTH 128

typedef struct {
  showtime_msg_type type;
  /* signals */
  int signum;
  /* jack */
  jack_port_id_t port;
  int reg;
  char name[SHOWTIME_MAX_CLIENT_NAME_LENGTH+1];
} showtime_msg_t;

/*** 0MQ ***/

static void showtime_zmq_init(showtime_app_t *app) {
  app->zmq_ctx = zmq_ctx_new();
  CHECK(app->zmq_ctx, "zmq_ctx_new() failed");

  app->zmq_sig_server_socket = zmq_socket(app->zmq_ctx, ZMQ_PAIR);
  CHECK(app->zmq_sig_server_socket, "cannot create zmq server socket for receiving signals");
  if (zmq_bind(app->zmq_sig_server_socket, "inproc://sig")) {
    DIE("zmq_bind() failed for signal server socket");
  }

  app->zmq_jack_server_socket = zmq_socket(app->zmq_ctx, ZMQ_PAIR);
  CHECK(app->zmq_jack_server_socket, "cannot create zmq server socket for receiving jack events");
  if (zmq_bind(app->zmq_jack_server_socket, "inproc://jack")) {
    DIE("zmq_bind() failed for jack server socket");
  }
}

static void showtime_zmq_done(showtime_app_t *app) {
  zmq_close(app->zmq_jack_server_socket);
  zmq_close(app->zmq_sig_server_socket);
  zmq_ctx_term(app->zmq_ctx);
}

/*** signals ***/

static void* showtime_signal_handler(void *arg) {
  showtime_app_t *app = (showtime_app_t*) arg;
  sigset_t ss;
  sigfillset(&ss);
  showtime_msg_t msg;
  int signum;
  app->zmq_sig_client_socket = zmq_socket(app->zmq_ctx, ZMQ_PAIR);
  CHECK(app->zmq_sig_client_socket, "cannot create zmq client socket for sending signals");
  if (zmq_connect(app->zmq_sig_client_socket, "inproc://sig"))
    DIE("zmq_connect() failed in signal handler thread");
  for (;;) {
    if (sigwait(&ss, &signum)) {
      DIE("sigwait() failed\n");
    }
    msg.type = SHOWTIME_SIGNAL_RECEIVED;
    msg.signum = signum;
    if (zmq_send(app->zmq_sig_client_socket, &msg, sizeof(msg), 0) != sizeof(msg))
      DIE("zmq_send() failed in signal handler thread");
    if (signum == SIGTERM || signum == SIGINT) break;
  }
  zmq_close(app->zmq_sig_client_socket);
}

static void showtime_signal_init(showtime_app_t *app) {
  sigset_t ss;
  sigfillset(&ss);
  /* block all signals in main thread */
  if (pthread_sigmask(SIG_BLOCK, &ss, &app->old_sigset) != 0) {
    DIE("pthread_sigmask() failed\n");
  }
  /* signals are handled in a dedicated thread which sends a 0MQ
     message to the main thread when a signal arrives */
  if (pthread_create(&app->signal_handler_thread, NULL, &showtime_signal_handler, app) != 0) {
    DIE("cannot create signal handler thread: pthread_create() failed\n");
  }
}

static void showtime_signal_done(showtime_app_t *app) {
  if (pthread_join(app->signal_handler_thread, NULL))
    DIE("pthread_join() failed for signal handler thread");
  /* restore signal mask */
  if (pthread_sigmask(SIG_SETMASK, &app->old_sigset, NULL) != 0)
    DIE("cannot restore signal mask: pthread_sigmask() failed");
}

/*** jack ***/

static void showtime_jack_thread_init_callback(void *arg) {
  showtime_app_t *app = (showtime_app_t*) arg;
  /* this callback gets called in two different threads - I don't know
     why - so we must be careful to avoid double initialization of the
     client socket */
  if (! app->zmq_jack_client_socket) {
    app->zmq_jack_client_socket = zmq_socket(app->zmq_ctx, ZMQ_PAIR);
    CHECK(app->zmq_jack_client_socket, "cannot create zmq client socket for sending jack events");
    if (zmq_connect(app->zmq_jack_client_socket, "inproc://jack"))
      DIE("zmq_connect() failed in jack thread");
  }
}

static void showtime_jack_port_registration_callback(jack_port_id_t port,
                                                     int reg,
                                                     void *arg) {
  showtime_app_t *app = (showtime_app_t*) arg;
  showtime_msg_t msg;
  msg.type = SHOWTIME_JACK_PORT_REGISTRATION;
  msg.port = port;
  msg.reg = reg;
  if (zmq_send(app->zmq_jack_client_socket, &msg, sizeof(msg), 0) != sizeof(msg))
    DIE("error while sending jack event message from port registration callback");
}

static void showtime_jack_client_registration_callback(const char *name,
                                                       int reg,
                                                       void *arg) {
  showtime_app_t *app = (showtime_app_t*) arg;
  showtime_msg_t msg;
  msg.type = SHOWTIME_JACK_CLIENT_REGISTRATION;
  if (strlen(name) > SHOWTIME_MAX_CLIENT_NAME_LENGTH)
    DIE("jack client registration callback: client name too long");
  strcpy(msg.name, name);
  msg.reg = reg;
  if (zmq_send(app->zmq_jack_client_socket, &msg, sizeof(msg), 0) != sizeof(msg))
    DIE("error while sending jack event message from client registration callback");
}

static void showtime_jack_init(showtime_app_t *app) {
  app->jack_client = jack_client_open(app->client_name, JackNoStartServer, 0);
  CHECK(app->jack_client, "jack_client_open() failed");
  LOG("connected to jackd with client name=[%s]", app->client_name);
  if (jack_set_thread_init_callback(app->jack_client,
                                    showtime_jack_thread_init_callback,
                                    app))
    DIE("jack_set_thread_init_callback() failed");
  if (jack_set_client_registration_callback(app->jack_client,
                                            showtime_jack_client_registration_callback,
                                            app))
    DIE("jack_set_client_registration_callback() failed");
  if (jack_set_port_registration_callback(app->jack_client,
                                          showtime_jack_port_registration_callback,
                                          app))
    DIE("jack_set_port_registration_callback() failed");
}

static void showtime_jack_start(showtime_app_t *app) {
  if (jack_activate(app->jack_client))
    DIE("jack_activate() failed");
}

static void showtime_jack_stop(showtime_app_t *app) {
  if (jack_deactivate(app->jack_client))
    DIE("jack_deactivate() failed");
}

static void showtime_jack_done(showtime_app_t *app) {
  jack_client_close(app->jack_client);
  LOG("disconnected from jackd", app->client_name);
  /* the 0MQ socket should be closed in the jack thread, but I don't
     know how to do that */
  zmq_close(app->zmq_jack_client_socket);
}

static void showtime_lua_init(showtime_app_t *app) {
  app->L = luaL_newstate();
  luaL_openlibs(app->L);
  CHECK(app->L, "luaL_newstate() failed");
  if (luaL_dofile(app->L, "showtime.lua"))
    lua_error(app->L);
}

static void showtime_lua_done(showtime_app_t *app) {
  lua_close(app->L);
}

static void showtime_init(showtime_app_t *app, const char *client_name) {
  app->client_name = client_name;
  showtime_zmq_init(app);
  showtime_signal_init(app);
  showtime_jack_init(app);
  showtime_lua_init(app);
  showtime_jack_start(app);
}

static void showtime_run(showtime_app_t *app) {
  zmq_pollitem_t items[2] = {
    { app->zmq_sig_server_socket,  0, ZMQ_POLLIN, 0 },
    { app->zmq_jack_server_socket, 0, ZMQ_POLLIN, 0 }
  };
  showtime_msg_t msg;
  int running = 1;
  while (running) {
    int nevents = zmq_poll(items, 2, -1);
    CHECK(nevents >= 0, "zmq_poll() failed");
    if (nevents > 0) {
      if (items[0].revents) {
        /* signal */
        if (zmq_recv(app->zmq_sig_server_socket, &msg, sizeof(msg), 0) != sizeof(msg))
          DIE("zmq_recv() failed in main thread when receiving signal message");
        assert(msg.type == SHOWTIME_SIGNAL_RECEIVED);
        LOG("got signal #%d: %s", msg.signum, strsignal(msg.signum));
        if (msg.signum == SIGTERM || msg.signum == SIGINT) {
          running = 0;
        }
      }
      if (items[1].revents) {
        /* jack event */
        if (zmq_recv(app->zmq_jack_server_socket, &msg, sizeof(msg), 0) != sizeof(msg))
          DIE("zmq_recv() failed in main thread when receiving jack event");
        switch (msg.type) {
        case SHOWTIME_JACK_PORT_REGISTRATION: {
          jack_port_t *port = jack_port_by_id(app->jack_client, msg.port);
          if (msg.reg) {
            LOG("registered jack port: %s", jack_port_name(port));
          }
          else {
            LOG("unregistered jack port: %s", jack_port_name(port));
          }
          break;
        }
        case SHOWTIME_JACK_CLIENT_REGISTRATION: {
          if (msg.reg) {
            LOG("registered jack client: %s", msg.name);
          }
          else {
            LOG("unregistered jack client: %s", msg.name);
          }
          break;
        }
        default:
          DIE("unknown msg.type in message received from jack thread: %d", msg.type);
        }
      }
    }
  }
}

static void showtime_done(showtime_app_t *app) {
  showtime_jack_stop(app);
  showtime_lua_done(app);
  showtime_jack_done(app);
  showtime_signal_done(app);
  showtime_zmq_done(app);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    showtime_usage();
  }
  showtime_app_t *app = calloc(1, sizeof(showtime_app_t));
  const char *client_name = argv[1];
  showtime_init(app, client_name);
  showtime_run(app);
  showtime_done(app);
  free(app);
  return 0;
}
