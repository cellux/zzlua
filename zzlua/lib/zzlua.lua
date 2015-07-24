-- statements in this file are executed once at zzlua startup

local ffi = require('ffi')

-- commonly used C types and functions

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

void *malloc (size_t size);
void free (void *ptr);

]]

local sf = string.format

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
local opt_e = false
while arg_index <= #arg do
   if arg[arg_index] == '-e' then
      opt_e = true
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

if opt_e and not script_path then
   -- if there was a script passed in via -e, but we didn't get a
   -- script path on the command line, then don't read from stdin
else
   zz_run(loadfile(script_path)) -- loadfile(nil) loads from stdin
end
