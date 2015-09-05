local ffi = require('ffi')
local gl = require('gl')

ffi.cdef [[
GLenum glewInit (void);
const GLubyte * glewGetErrorString (GLenum error);
extern GLboolean glewExperimental;
]]

local M = {}

function M.init()
   assert(gl.GetError() == gl.GL_NO_ERROR)
   local rv = ffi.C.glewInit()
   if rv ~= 0 then
      ef("glewInit() failed: %s", ffi.C.glewGetErrorString(rv))
   end
   -- a successful glewInit() may still produce GL errors in the
   -- background. according to some sources, these errors can be
   -- safely ignored so we swallow them here.
   while true do
      if gl.GetError() == gl.GL_NO_ERROR then break end
   end
end

return M
