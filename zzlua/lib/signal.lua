local ffi = require('ffi')
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

int kill (__pid_t __pid, int __sig);

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

return M
