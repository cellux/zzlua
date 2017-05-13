local ffi = require('ffi')
local sched = require('sched')
local util = require('util')

ffi.cdef [[

struct zz_trigger {
  int fd;
};

void zz_trigger_fire(struct zz_trigger *t);

]]

local M = {}

local Trigger_mt = {}

function Trigger_mt:fd()
   return self.fd
end

function Trigger_mt:poll()
   assert(sched.running())
   sched.poll(self.fd, "r")
   local buf = ffi.new("uint64_t[1]")
   buf[0] = 0
   local nbytes = ffi.C.read(self.fd, buf, 8)
   assert(nbytes==8)
   assert(buf[0]==1)
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

local Trigger = ffi.metatype("struct zz_trigger", Trigger_mt)

function M.Trigger()
   local fd = util.check_errno("eventfd", ffi.C.eventfd(0, ffi.C.EFD_NONBLOCK))
   return Trigger(fd)
end

return setmetatable(M, { __call = M.Trigger })
