local ffi = require("ffi")

ffi.cdef [[
typedef int __pid_t;

__pid_t getpid();
__pid_t fork ();
int     kill (__pid_t __pid, int __sig);

typedef struct {
  unsigned long int __val[(1024 / (8 * sizeof (unsigned long int)))];
} __sigset_t;
typedef __sigset_t sigset_t;

int sigfillset (sigset_t *__set);
int sigaddset (sigset_t *__set, int __signo);
int sigdelset (sigset_t *__set, int __signo);
int sigismember (const sigset_t *__set, int __signo);

int pthread_sigmask(int how, const sigset_t *set, sigset_t *oldset);

int chdir(const char *path);

char * getenv (const char *NAME);
int execvp (const char *FILENAME, char *const ARGV[]);
]]

local function check_ok(funcname, okvalue, rv)
   if rv ~= okvalue then
      error(sf("%s() failed", funcname), 2)
   else
      return rv
   end
end

local function check_bad(funcname, badvalue, rv)
   if rv == badvalue then
      error(sf("%s() failed", funcname), 2)
   else
      return rv
   end
end

local M = {}

function M.getpid()
   return ffi.C.getpid()
end

function M.kill(pid, sig)
   return check_bad("kill", 0, ffi.C.kill(pid, sig))
end

function M.fork()
   return util.check_bad("fork", -1, ffi.C.fork())
end

function M.getenv(name)
   local value = ffi.C.getenv(name)
   if value == nil then
      return nil
   else
      return ffi.string(value)
   end
end

function M.execvp(path, argv)
   -- stringify args
   for i=1,#argv do
      argv[i] = tostring(argv[i])
   end
   -- build const char* argv[] for execvp()
   local execvp_argv = ffi.new("char*[?]", #argv+1)
   for i=1,#argv do
      execvp_argv[i-1] = ffi.cast("char*", argv[i])
   end
   execvp_argv[#argv] = nil
   check_bad("execvp", -1, ffi.C.execvp(path, execvp_argv))
end

local SIG_BLOCK   = 0
local SIG_UNBLOCK = 1
local SIG_SETMASK = 2

function M.block_all_signals()
   local ss = ffi.new('sigset_t')
   ffi.C.sigfillset(ss)
   return check_ok("pthread_sigmask", 0,
                   ffi.C.pthread_sigmask(SIG_BLOCK, ss, nil))
end

function M.unblock_all_signals()
   local ss = ffi.new('sigset_t')
   ffi.C.sigfillset(ss)
   return check_ok("pthread_sigmask", 0,
                   ffi.C.pthread_sigmask(SIG_UNBLOCK, ss, nil))
end

function M.chdir(path)
   return util.check_ok("chdir", 0, ffi.C.chdir(path))
end

return M
