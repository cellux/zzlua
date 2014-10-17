#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <signal.h>
#include <pthread.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "buffer.h"
#include "cmp.h"
#include "nn.h"
#include "pubsub.h"

/* most of this comes from LuaJIT */

static const char *progname = "zzlua";

static pthread_t signal_handler_thread_id;
static sigset_t saved_sigset;

static void *signal_handler_thread(void *arg) {
  sigset_t ss;
  siginfo_t siginfo;
  int signum;
  int event_socket;
  int endpoint_id;
  unsigned char msg_buf[32];
  cmp_ctx_t cmp_ctx;
  buffer_t cmp_buf;
  cmp_buffer_state cmp_buf_state;

  buffer_init(&cmp_buf, msg_buf, 0, 32, false);
  cmp_buf_state.buffer = &cmp_buf;
  cmp_init(&cmp_ctx, &cmp_buf_state, cmp_buffer_reader, cmp_buffer_writer);

  event_socket = nn_socket(AF_SP, NN_PUB);
  if (event_socket < 0) {
    fprintf(stderr, "Cannot create event socket in signal_handler_thread, nn_socket() failed\n");
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

void setup_signal_handler_thread() {
  sigset_t ss;
  sigfillset(&ss);
  /* block all signals in main thread */
  if (pthread_sigmask(SIG_BLOCK, &ss, &saved_sigset) != 0) {
    fprintf(stderr, "pthread_sigmask() failed\n");
    exit(1);
  }
  /* signals are handled in a dedicated thread which sends an event to
     the Lua scheduler when a signal arrives */
  if (pthread_create(&signal_handler_thread_id,
                     NULL,
                     signal_handler_thread,
                     NULL) != 0) {
    fprintf(stderr, "cannot create signal handler thread: pthread_create() failed\n");
    exit(1);
  }
}

static void l_message(const char *msg)
{
  fprintf(stderr, "%s\n", msg);
  fflush(stderr);
}

static int report(lua_State *L, int status)
{
  if (status && !lua_isnil(L, -1)) {
    const char *msg = lua_tostring(L, -1);
    if (msg == NULL) msg = "(error object is not a string)";
    l_message(msg);
    lua_pop(L, 1);
  }
  return status;
}

static struct Smain {
  char **argv;
  int argc;
  int status;
} smain;

static void getargs(lua_State *L, int argc, char **argv) {
  int i;
  lua_createtable(L, argc, 0);
  for (i=1; i<argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i);
  }
  lua_setglobal(L, "arg");
}

static int traceback(lua_State *L)
{
  if (!lua_isstring(L, 1)) { /* Non-string error object? Try metamethod. */
    if (lua_isnoneornil(L, 1) ||
        !luaL_callmeta(L, 1, "__tostring") ||
        !lua_isstring(L, -1))
      return 1;  /* Return non-string error object. */
    lua_remove(L, 1);  /* Replace object by result of __tostring metamethod. */
  }
  luaL_traceback(L, L, lua_tostring(L, 1), 1);
  return 1;
}

static int docall(lua_State *L, int narg, int clear)
{
  int status;
  int base = lua_gettop(L) - narg;  /* function index */
  lua_pushcfunction(L, traceback);  /* push traceback function */
  lua_insert(L, base);  /* put it under chunk and args */
  status = lua_pcall(L, narg, (clear ? 0 : LUA_MULTRET), base);
  lua_remove(L, base);  /* remove traceback function */
  /* force a complete garbage collection in case of errors */
  if (status != 0) lua_gc(L, LUA_GCCOLLECT, 0);
  return status;
}

static int pmain(lua_State *L)
{
  struct Smain *s = &smain;
  lua_gc(L, LUA_GCSTOP, 0);  /* stop collector during initialization */
  //luaL_openlibs(L);  /* open libraries */
  luaopen_base(L);
  luaopen_math(L);
  luaopen_string(L);
  luaopen_table(L);
  //luaopen_io(L);
  //luaopen_os(L);
  luaopen_package(L);
  //luaopen_debug(L);
  luaopen_bit(L);
  //luaopen_jit(L);
  luaopen_ffi(L);
  lua_gc(L, LUA_GCRESTART, -1);
  getargs(L, s->argc, s->argv);
  lua_getglobal(L, "require");
  lua_pushstring(L, "zzlua");
  s->status = report(L, docall(L, 1, 1));
  return s->status;
}

int main(int argc, char **argv)
{
  progname = argv[0];
  int status;
  lua_State *L = luaL_newstate();
  if (L == NULL) {
    l_message("cannot create Lua state: not enough memory");
    return EXIT_FAILURE;
  }
  smain.argc = argc;
  smain.argv = argv;
  status = lua_cpcall(L, pmain, NULL);
  report(L, status);
  lua_close(L);
  return (status || smain.status) ? EXIT_FAILURE : EXIT_SUCCESS;
}
