-- statements in this file are executed once at zzlua startup

local ffi = require('ffi')
local sched = require('sched')
local sf = string.format

local function signal_handler(data)
   local signum, pid = unpack(data)
   --print(sf("got signal %d from pid %d", signum, pid))
   if signum == 15 or signum == 2 then
      sched.emit('quit')
   end
end

sched.on_forever('signal', signal_handler)

ffi.cdef [[
void setup_signal_handler_thread();
]]

ffi.C.setup_signal_handler_thread()

local function zzlua_run(chunk, err)
   if chunk then
      chunk()
   else
      error(err, 0)
   end
end

--[[ main ]]--

-- process zzlua options

local arg_index = 1
while arg_index <= #arg do
   if arg[arg_index] == '-e' then
      arg_index = arg_index + 1
      local script = arg[arg_index]
      zzlua_run(loadstring(script))
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
zzlua_run(loadfile(script_path)) -- loadfile(nil) loads from stdin
