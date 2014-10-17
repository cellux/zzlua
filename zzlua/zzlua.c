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

static lua_State *gL = NULL;
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

static void lstop(lua_State *L, lua_Debug *ar)
{
  (void)ar;  /* unused arg. */
  lua_sethook(L, NULL, 0, 0);
  /* Avoid luaL_error -- a C hook doesn't add an extra frame. */
  luaL_where(L, 0);
  lua_pushfstring(L, "%sinterrupted!", lua_tostring(L, -1));
  lua_error(L);
}

static void laction(int i)
{
  signal(i, SIG_DFL); /* if another SIGINT happens before lstop,
                         terminate process (default action) */
  lua_sethook(gL, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

static void print_usage(void)
{
  fprintf(stderr, "usage: %s [options]... [script [args]...].\n", progname);
  fflush(stderr);
}

static void l_message(const char *pname, const char *msg)
{
  if (pname) fprintf(stderr, "%s: ", pname);
  fprintf(stderr, "%s\n", msg);
  fflush(stderr);
}

static int report(lua_State *L, int status)
{
  if (status && !lua_isnil(L, -1)) {
    const char *msg = lua_tostring(L, -1);
    if (msg == NULL) msg = "(error object is not a string)";
    l_message(progname, msg);
    lua_pop(L, 1);
  }
  return status;
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
  //signal(SIGINT, laction);
  status = lua_pcall(L, narg, (clear ? 0 : LUA_MULTRET), base);
  //signal(SIGINT, SIG_DFL);
  lua_remove(L, base);  /* remove traceback function */
  /* force a complete garbage collection in case of errors */
  if (status != 0) lua_gc(L, LUA_GCCOLLECT, 0);
  return status;
}

static int getargs(lua_State *L, char **argv, int n)
{
  int narg;
  int i;
  int argc = 0;
  while (argv[argc]) argc++;  /* count total number of arguments */
  narg = argc - (n + 1);  /* number of arguments to the script */
  luaL_checkstack(L, narg + 3, "too many arguments to script");
  for (i = n+1; i < argc; i++)
    lua_pushstring(L, argv[i]);
  lua_createtable(L, narg, n + 1);
  for (i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i - n);
  }
  return narg;
}

static int dofile(lua_State *L, const char *name)
{
  int status = luaL_loadfile(L, name) || docall(L, 0, 1);
  return report(L, status);
}

static int dostring(lua_State *L, const char *s, const char *name)
{
  int status = luaL_loadbuffer(L, s, strlen(s), name) || docall(L, 0, 1);
  return report(L, status);
}

static int dolibrary(lua_State *L, const char *name)
{
  lua_getglobal(L, "require");
  lua_pushstring(L, name);
  return report(L, docall(L, 1, 1));
}

static int handle_script(lua_State *L, char **argv, int n)
{
  int status;
  const char *fname;
  int narg = getargs(L, argv, n);  /* collect arguments */
  lua_setglobal(L, "arg");
  fname = argv[n];
  if (strcmp(fname, "-") == 0 && strcmp(argv[n-1], "--") != 0)
    fname = NULL;  /* stdin */
  status = luaL_loadfile(L, fname);
  lua_insert(L, -(narg+1));
  if (status == 0)
    status = docall(L, narg, 0);
  else
    lua_pop(L, narg);
  return report(L, status);
}

#define FLAGS_INTERACTIVE	1
#define FLAGS_VERSION		2
#define FLAGS_EXEC		4
#define FLAGS_OPTION		8
#define FLAGS_NOENV		16

static int collectargs(char **argv, int *flags)
{
  int i;
  for (i = 1; argv[i] != NULL; i++) {
    if (argv[i][0] != '-')  /* Not an option? */
      return i;
    switch (argv[i][1]) {  /* Check option. */
    case 'e': {
      *flags |= FLAGS_EXEC;
      const char *chunk = argv[i] + 2;
      if (*chunk == '\0') chunk = argv[++i];
      break;
    }
    default:
      return -1;  /* invalid option */
    }
  }
  return 0;
}

static int runargs(lua_State *L, char **argv, int n)
{
  int i;
  for (i = 1; i < n; i++) {
    if (argv[i] == NULL) continue;
    lua_assert(argv[i][0] == '-');
    switch (argv[i][1]) {  /* option */
    case 'e': {
      const char *chunk = argv[i] + 2;
      if (*chunk == '\0') chunk = argv[++i];
      lua_assert(chunk != NULL);
      if (dostring(L, chunk, "=(command line)") != 0)
        return 1;
      break;
    }
    default:
      break;
    }
  }
  return 0;
}

static struct Smain {
  char **argv;
  int argc;
  int status;
} smain;

static int pmain(lua_State *L)
{
  struct Smain *s = &smain;
  char **argv = s->argv;
  int script;
  int flags = 0;
  gL = L;
  if (argv[0] && argv[0][0]) progname = argv[0];
  script = collectargs(argv, &flags);
  if (script < 0) {  /* invalid args? */
    print_usage();
    s->status = 1;
    return 0;
  }
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
  dolibrary(L, "zzlua");
  lua_gc(L, LUA_GCRESTART, -1);
  s->status = runargs(L, argv, (script > 0) ? script : s->argc);
  if (s->status != 0) return 0;
  if (script) {
    s->status = handle_script(L, argv, script);
    if (s->status != 0) return 0;
  }
  if (script == 0 && !(flags & FLAGS_EXEC)) {
    dofile(L, NULL);  /* executes stdin as a file */
  }
  return 0;
}

int main(int argc, char **argv)
{
  int status;
  lua_State *L = luaL_newstate();
  if (L == NULL) {
    l_message(argv[0], "cannot create state: not enough memory");
    return EXIT_FAILURE;
  }
  smain.argc = argc;
  smain.argv = argv;
  status = lua_cpcall(L, pmain, NULL);
  report(L, status);
  lua_close(L);
  return (status || smain.status) ? EXIT_FAILURE : EXIT_SUCCESS;
}
