local adt = require('adt')
local errno = require('errno')

local M = {}

function M.round(x)
   if x >= 0 then
      return math.floor(x+0.5)
   else
      return math.ceil(x-0.5)
   end
end

function M.align_down(x, alignment)
   return x - x % alignment
end

function M.align_up(x, alignment)
   return x + (alignment - (x % alignment)) % alignment
end

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

function M.Accumulator()
   local self = {
      last = nil,
      n = 0,
      sum = 0,
      avg = 0,
      min = nil,
      max = nil,
   }
   function self:feed(x)
      self.n = self.n + 1
      self.sum = self.sum + x
      self.avg = self.sum / self.n
      if not self.max or x > self.max then
         self.max = x
      end
      if not self.min or x < self.min then
         self.min = x
      end
      self.last = x
   end
   return setmetatable(self, { __call = self.feed })
end

function M.Class(parent)
   local class = {}
   local mt = { __index = parent }
   function mt:__call(...)
      local self = {}
      if class.create then
         self = class:create(...)
      elseif select('#', ...)==1 then
         local arg = select(1, ...)
         if type(arg)=="table" then
            self = arg
         end
      end
      return setmetatable(self, { __index = class })
   end
   return setmetatable(class, mt)
end

function M.EventEmitter(self, invoke_fn)
   self = self or {}
   invoke_fn = invoke_fn or function(cb, evtype, ...) cb(...) end
   local callbacks = {}
   function self:on(evtype, cb)
      if not callbacks[evtype] then
         callbacks[evtype] = adt.List()
      end
      callbacks[evtype]:push(cb)
   end
   function self:off(evtype, cb)
      if callbacks[evtype] then
         local cbs = callbacks[evtype]
         local i = cbs:index(cb)
         if i then
            cbs:remove_at(i)
         end
         if callbacks[evtype]:empty() then
            callbacks[evtype] = nil
         end
      end
   end
   function self:emit(evtype, ...)
      local cbs = callbacks[evtype]
      if cbs then
         for cb in cbs:itervalues() do
            invoke_fn(cb, evtype, ...)
         end
      end
   end
   return self
end

function M.lines(s)
   local index = 1
   local function next()
      local rv = nil
      if index <= #s then
         local lf_pos = s:find("\n", index, true)
         if lf_pos then
            rv = s:sub(index, lf_pos-1)
            index = lf_pos+1
         else
            rv = s:sub(index)
            index = #s+1
         end
      end
      return rv
   end
   return next
end

return M
