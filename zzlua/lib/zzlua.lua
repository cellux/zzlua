-- statements in this file are executed once at zzlua startup

local ffi = require('ffi')

-- some commonly used C types

ffi.cdef [[
  typedef long int ssize_t;

  /* types of struct stat fields */

  typedef unsigned long long int __dev_t;
  typedef unsigned long int __ino_t;
  typedef unsigned int __mode_t;
  typedef unsigned int __nlink_t;
  typedef unsigned int __uid_t;
  typedef unsigned int __gid_t;
  typedef long int __off_t;
  typedef long int __blksize_t;
  typedef long int __blkcnt_t;

  typedef long int __time_t;
  typedef long int __syscall_slong_t;

  struct timespec {
    __time_t tv_sec;
    __syscall_slong_t tv_nsec;
  };
]]

local sched = require('sched')
local sf = string.format

-- setup signal handler

local function signal_handler(data)
   local signum, pid = unpack(data)
   --print(sf("got signal %d from pid %d", signum, pid))
   if signum == 15 or signum == 2 then
      sched.emit('quit')
   end
end

sched.on_forever('signal', signal_handler)

ffi.cdef "void zz_setup_signal_handler_thread();"

ffi.C.zz_setup_signal_handler_thread()

--[[ main ]]--

local function zz_run(chunk, err)
   if chunk then
      chunk()
   else
      error(err, 0)
   end
end

-- process zzlua options

local arg_index = 1
while arg_index <= #arg do
   if arg[arg_index] == '-e' then
      arg_index = arg_index + 1
      local script = arg[arg_index]
      zz_run(loadstring(script))
   else
      -- the first non-option arg is the path of the script to run
      break
   end
   arg_index = arg_index + 1
end

-- run zzlua script (from specified file or stdin)

local script_path = arg[arg_index]
local script_args = {}
for i=arg_index+1,#arg do
   table.insert(script_args, arg[i])
end
arg = script_args -- the script shall not see any zzlua options
zz_run(loadfile(script_path)) -- loadfile(nil) loads from stdin
