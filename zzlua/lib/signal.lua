local ffi = require('ffi')
local sys = require('sys') -- for pid_t
local util = require('util')

ffi.cdef [[

typedef struct {
  unsigned long int __val[(1024 / (8 * sizeof (unsigned long int)))];
} __sigset_t;
typedef __sigset_t sigset_t;

int sigemptyset (sigset_t *__set);
int sigfillset (sigset_t *__set);
int sigaddset (sigset_t *__set, int __signo);
int sigdelset (sigset_t *__set, int __signo);
int sigismember (const sigset_t *__set, int __signo);

int pthread_sigmask(int how, const sigset_t *set, sigset_t *oldset);

int kill (pid_t __pid, int __sig);

typedef unsigned long int pthread_t;

typedef union {
  char __size[56];
  long int __align;
} pthread_attr_t;

int pthread_create(pthread_t *thread,
                   const pthread_attr_t *attr,
                   void *(*start_routine) (void *),
                   void *arg);

void *zz_signal_handler_thread(void *arg);

]]

local SIG_BLOCK   = 0
local SIG_UNBLOCK = 1
local SIG_SETMASK = 2

local M = {}

local function sigmask(how, signum)
   local ss = ffi.new('sigset_t')
   if signum then
      ffi.C.sigemptyset(ss)
      ffi.C.sigaddset(ss, signum)
   else
      ffi.C.sigfillset(ss)
   end
   return util.check_ok("pthread_sigmask", 0,
                        ffi.C.pthread_sigmask(how, ss, nil))
end

function M.block(signum)
   return sigmask(SIG_BLOCK, signum)
end

function M.unblock(signum)
   return sigmask(SIG_UNBLOCK, signum)
end

function M.kill(pid, sig)
   return util.check_bad("kill", 0, ffi.C.kill(pid, sig))
end

function M.setup_signal_handler_thread()
   -- block all signals in the main thread
   M.block()
   -- signals are handled in a dedicated thread which sends an event
   -- to the Lua scheduler when a signal arrives
   local thread_id = ffi.new("pthread_t[1]")
   local rv = ffi.C.pthread_create(thread_id,
                                   nil,
                                   ffi.C.zz_signal_handler_thread,
                                   nil)
   if rv ~= 0 then
      error("cannot create signal handler thread: pthread_create() failed")
   end
end

return M
