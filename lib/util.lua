local errno = require('errno')

local M = {}

function M.check_ok(funcname, okvalue, rv)
   if rv ~= okvalue then
      error(sf("%s() failed: %s", funcname, rv), 2)
   else
      return rv
   end
end

function M.check_bad(funcname, badvalue, rv)
   if rv == badvalue then
      error(sf("%s() failed: %s", funcname, rv), 2)
   else
      return rv
   end
end

function M.check_errno(funcname, rv)
   if rv == -1 then
      error(sf("%s() failed: %s", funcname, errno.strerror()), 2)
   else
      return rv
   end
end

return M
