local ffi = require("ffi")

ffi.cdef [[
typedef int __pid_t;
__pid_t getpid();
]]

local M = {}

function M.getpid()
   return ffi.C.getpid()
end

return M
