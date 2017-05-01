local ffi = require('ffi')
local bit = require('bit')
local util = require('util')

ffi.cdef [[
enum EPOLL_EVENTS {
  EPOLLIN      = 0x0001,
  EPOLLPRI     = 0x0002,
  EPOLLOUT     = 0x0004,
  EPOLLRDNORM  = 0x0040,
  EPOLLRDBAND  = 0x0080,
  EPOLLWRNORM  = 0x0100,
  EPOLLWRBAND  = 0x0200,
  EPOLLMSG     = 0x0400,
  EPOLLERR     = 0x0008,
  EPOLLHUP     = 0x0010,
  EPOLLRDHUP   = 0x2000,
  EPOLLWAKEUP  = 1u << 29,
  EPOLLONESHOT = 1u << 30,
  EPOLLET      = 1u << 31
};

enum {
  EPOLL_CTL_ADD = 1,
  EPOLL_CTL_DEL = 2,
  EPOLL_CTL_MOD = 3
};

typedef union epoll_data {
  void *ptr;
  int fd;
  uint32_t u32;
  uint64_t u64;
} epoll_data_t;

struct epoll_event {
  uint32_t events;	/* Epoll events */
  epoll_data_t data;	/* User data variable */
} __attribute__((__packed__));

extern int epoll_create (int size);
extern int epoll_create1 (int flags);
extern int epoll_ctl (int epfd, int op, int fd, struct epoll_event *event);
extern int epoll_wait (int epfd, struct epoll_event *events, int maxevents, int timeout);

extern int close (int fd);

]]

local Poller_mt = {}

local event_values = {
   ["r"] = ffi.C.EPOLLIN,
   ["w"] = ffi.C.EPOLLOUT,
   ["1"] = ffi.C.EPOLLONESHOT,
}

local function parse_events(events)
   if type(events)=="string" then
      local rv = 0
      for i=1,#events do
         local e = events:sub(i,i)
         local ev = event_values[e]
         if not ev then
            ef("unknown event code: '%s' in '%s'", e, events)
         end
         rv = bit.bor(rv, ev)
      end
      return rv
   else
      return events
   end
end

function Poller_mt:fd()
   return self.epfd
end

function Poller_mt:ctl(op, fd, events, data)
   local epoll_event = ffi.new("struct epoll_event")
   epoll_event.events = events and parse_events(events) or 0
   epoll_event.data.fd = data or 0
   return util.check_errno("epoll_ctl", ffi.C.epoll_ctl(self.epfd, op, fd, epoll_event))
end

function Poller_mt:add(fd, events, data)
   return self:ctl(ffi.C.EPOLL_CTL_ADD, fd, events, data)
end

function Poller_mt:mod(fd, events, data)
   return self:ctl(ffi.C.EPOLL_CTL_MOD, fd, events, data)
end

function Poller_mt:del(fd, events, data)
   return self:ctl(ffi.C.EPOLL_CTL_DEL, fd, events, data)
end

function Poller_mt:wait(timeout, process)
   local rv = util.check_errno("epoll_wait",
                               ffi.C.epoll_wait(self.epfd, self.events,
                                                self.maxevents, timeout))
   if rv > 0 then
      for i = 1,rv do
         local event = self.events[i-1]
         process(event.events, event.data.fd)
      end
   end
end

function Poller_mt:close()
   if self.epfd >= 0 then
      local rv
      rv = ffi.C.close(self.epfd)
      util.check_ok("close", 0, rv)
      self.epfd = -1
   end
   return 0
end

Poller_mt.__index = Poller_mt
Poller_mt.__gc = Poller_mt.close

local function Poller(epfd, maxevents)
   maxevents = maxevents or 64
   local self = {
      epfd = epfd,
      maxevents = maxevents,
      events = ffi.new("struct epoll_event[?]", maxevents),
   }
   return setmetatable(self, Poller_mt)
end

local M = {}

function M.create(maxevents)
   local epfd = util.check_errno("epoll_create", ffi.C.epoll_create(1))
   return Poller(epfd, maxevents)
end

M.poller_factory = M.create

return M
