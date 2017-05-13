local ffi = require('ffi')
local sched = require('sched')
local util = require('util')
local errno = require('errno')

ffi.cdef [[

typedef struct {
  int fd;
} zz_trigger;

void zz_trigger_fire(zz_trigger *t);

]]

local M = {}

local Trigger_mt = {}

function Trigger_mt:poll()
   local buf = ffi.new("uint64_t[1]")
   while true do
      if sched.running() then
         sched.poll(self.fd, "r")
      end
      buf[0] = 0
      local nbytes = ffi.C.read(self.fd, buf, 8)
      if nbytes == 8 then
         assert(tonumber(buf[0])==1)
         break
      elseif nbytes == -1 then
         local errnum = errno.errno()
         if errnum ~= ffi.C.EAGAIN then
            ef("poll() failed: %s", errno.strerror(errnum))
         end
      else
         ef("poll() failed: nbytes=%d, expected 8", nbytes)
      end
   end
end

function Trigger_mt:fire()
   local buf = ffi.new("uint64_t[1]")
   buf[0] = 1
   ffi.C.write(self.fd, buf, 8)
end

function Trigger_mt:delete()
   if self.fd ~= 0 then
      ffi.C.close(self.fd)
      self.fd = 0
   end
end

Trigger_mt.__index = Trigger_mt
Trigger_mt.__gc = Trigger_mt.delete

local Trigger = ffi.metatype("zz_trigger", Trigger_mt)

function M.Trigger()
   local fd = util.check_errno("eventfd", ffi.C.eventfd(0, ffi.C.EFD_NONBLOCK))
   return Trigger(fd)
end

return setmetatable(M, { __call = M.Trigger })
