local ffi = require('ffi')
local util = require('util')

ffi.cdef [[

typedef int __pid_t;
typedef __pid_t pid_t;

/* process identification */

pid_t getpid ();
pid_t getppid ();

/* process creation */

pid_t fork ();

/* execution */

int system (const char *COMMAND);
int execv (const char *FILENAME,
           char *const ARGV[]);
int execl (const char *FILENAME,
           const char *ARG0,
           ...);
int execve (const char *FILENAME,
            char *const ARGV[],
            char *const ENV[]);
int execvp (const char *FILENAME,
            char *const ARGV[]);
int execlp (const char *FILENAME,
            const char *ARG0,
            ...);

/* process completion */

pid_t waitpid (pid_t PID, int *STATUSPTR, int OPTIONS);

/* process state */

int chdir (const char *path);

]]

local M = {}

function M.getpid()
   return ffi.C.getpid()
end

function M.fork()
   return util.check_bad("fork", -1, ffi.C.fork())
end

function M.system(command)
   return ffi.C.system(command)
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
   util.check_bad("execvp", -1, ffi.C.execvp(path, execvp_argv))
end

function M.waitpid(pid, options)
   options = options or 0
   local status = ffi.new("int[1]")
   local rv = util.check_bad("waitpid", -1, ffi.C.waitpid(pid, status, options))
   return rv, tonumber(status[0])
end

function M.chdir(path)
   return util.check_ok("chdir", 0, ffi.C.chdir(path))
end

return M
