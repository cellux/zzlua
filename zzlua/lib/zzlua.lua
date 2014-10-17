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

-- find script arg on command line, load and execute

local arg_index = 1
while arg_index <= #arg do
   if arg[arg_index] == '-e' then
      arg_index = arg_index + 1
      local expr = arg[arg_index]
      local chunk, err = loadstring(expr)
      if chunk then
         chunk()
      else
         error("error in chunk given to -e: "..err)
      end
   else
      -- found script arg
      break
   end
   arg_index = arg_index + 1
end

local script_path = arg[arg_index] or '-'
local script_args = {}
for i=arg_index+1,#arg do
   table.insert(script_args, arg[i])
end
arg = script_args
local chunk, err
if script_path == '-' then
   chunk, err = loadfile()
else
   chunk, err = loadfile(script_path)
end
if chunk then
   chunk()
else
   error(sf("error in %s: %s", script_path, err))
end
