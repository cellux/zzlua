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
