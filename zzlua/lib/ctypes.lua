-- architecture-dependent definitions of commonly used C types

local ffi = require('ffi')

ffi.cdef [[
   typedef long int ssize_t;
   typedef long int __off_t;
]]

if ffi.abi("32bit") then
elseif ffi.abi("64bit") then
end
