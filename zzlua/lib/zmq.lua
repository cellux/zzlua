local ffi = require('ffi')
local sf = string.format

ffi.cdef [[
void zmq_version (int *major, int *minor, int *patch);
int zmq_errno (void);
const char *zmq_strerror (int errnum);

void *zmq_ctx_new (void);
int zmq_ctx_term (void *context);

void *zmq_socket (void *, int type);
int zmq_setsockopt (void *s, int option, const void *optval, size_t optvallen);
int zmq_getsockopt (void *s, int option, void *optval, size_t *optvallen);
int zmq_bind (void *s, const char *addr);
int zmq_unbind (void *s, const char *addr);
int zmq_connect (void *s, const char *addr);
int zmq_disconnect (void *s, const char *addr);
int zmq_send (void *s, const void *buf, size_t len, int flags);
int zmq_recv (void *s, void *buf, size_t len, int flags);
int zmq_close (void *s);

typedef struct {
    void *socket;
    int fd;
    short events;
    short revents;
} zmq_pollitem_t;

int zmq_poll (zmq_pollitem_t *items, int nitems, long timeout);

struct zmq_Context_ct {
  void *ctx;
};

struct zmq_Socket_ct {
  void *socket;
};

]]

local zmq = ffi.load("zmq")

local function zmq_error()
   return ffi.string(zmq.zmq_strerror(zmq.zmq_errno()))
end

-- Socket

local Socket_mt = {}

local function check_rv(rv, func)
   if rv ~= 0 then
      error(sf("%s() failed: %s", func, zmq_error()), 2)
   end
   return rv
end

function Socket_mt:setsockopt(option, optval, optvallen)
   if type(optval)=="string" and optvallen == nil then
      optvallen = #optval
   end
   return check_rv(zmq.zmq_setsockopt(self.socket, option, optval, optvallen), "zmq_setsockopt")
end

function Socket_mt:bind(addr)
   return check_rv(zmq.zmq_bind(self.socket, addr), "zmq_bind")
end

function Socket_mt:unbind(addr)
   return check_rv(zmq.zmq_unbind(self.socket, addr), "zmq_unbind")
end

function Socket_mt:connect(addr)
   return check_rv(zmq.zmq_connect(self.socket, addr), "zmq_connect")
end

function Socket_mt:disconnect(addr)
   return check_rv(zmq.zmq_disconnect(self.socket, addr), "zmq_disconnect")
end

function Socket_mt:send(buf, len, flags)
   if type(buf)=="string" and len == nil then
      len = #buf
   end
   flags = flags or 0
   local bytes_sent = zmq.zmq_send(self.socket, buf, len, flags)
   if bytes_sent == -1 then
      error(sf("zmq_send() failed: %s", zmq_error()))
   end
   return bytes_sent
end

function Socket_mt:recv(buf, len, flags)
   flags = flags or 0
   local bytes_received = zmq.zmq_recv(self.socket, buf, len, flags)
   if bytes_received == -1 then
      error(sf("zmq_recv() failed: %s", zmq_error()))
   end
   return bytes_received
end

function Socket_mt:close()
   return check_rv(zmq.zmq_close(self.socket), "zmq_close")
end

function Socket_mt.__eq(s1, s2)
   return s1.socket == s2.socket
end

Socket_mt.__index = Socket_mt

local Socket = ffi.metatype("struct zmq_Socket_ct", Socket_mt)

-- Context

local Context_mt = {}

function Context_mt:Socket(type)
   local socket = zmq.zmq_socket(self.ctx, type)
   if socket == nil then
      error("zmq_socket() failed")
   end
   return Socket(socket)
end

function Context_mt:term()
   return zmq.zmq_ctx_term(self.ctx)
end

function Context_mt.__eq(c1, c2)
   return c1.ctx == c2.ctx
end

Context_mt.__index = Context_mt

local Context = ffi.metatype("struct zmq_Context_ct", Context_mt)

--

local M = {}

-- socket types
M.PAIR   = 0
M.PUB    = 1
M.SUB    = 2
M.REQ    = 3
M.REP    = 4
M.DEALER = 5
M.ROUTER = 6
M.PULL   = 7
M.PUSH   = 8
M.XPUB   = 9
M.XSUB   = 10
M.STREAM = 11

-- socket options (only what we need)
M.SUBSCRIBE   = 6
M.UNSUBSCRIBE = 7
M.LINGER      = 17

-- poll events
M.POLLIN  = 1
M.POLLOUT = 2
M.POLLERR = 4

function M.version()
   local version = ffi.new("int[3]")
   zmq.zmq_version(version, version+1, version+2)
   return tonumber(version[0]), tonumber(version[1]), tonumber(version[2])
end

function M.Context()
   local ctx = zmq.zmq_ctx_new()
   if ctx == nil then
      error("zmq_ctx_new() failed")
   end
   return Context(ctx)
end

-- Poll

local Poll_mt = {}

function Poll_mt:add(socket, fd, events)
   table.insert(self.items, {socket, fd, events})
   self.changed = true
end

function Poll_mt:populate_zmq_pollitems()
   self.zmq_pollitems = ffi.new("zmq_pollitem_t[?]", #self.items)
   for i=1,#self.items do
      self.zmq_pollitems[i-1].socket = self.items[i][1].socket
      self.zmq_pollitems[i-1].fd = self.items[i][2]
      self.zmq_pollitems[i-1].events = self.items[i][3]
      self.zmq_pollitems[i-1].revents = 0
   end
end

function Poll_mt:__call(timeout)
   if self.zmq_pollitems == nil or self.changed then
      self:populate_zmq_pollitems()
      self.changed = false
   end
   local rv = zmq.zmq_poll(self.zmq_pollitems, #self.items, timeout)
   if rv == -1 then
      error(sf("zmq_poll() failed: %s", zmq_error()))
   end
   return rv
end

function Poll_mt:__index(k)
   if type(k)=="number" then
      return self.zmq_pollitems[k]
   else
      return rawget(Poll_mt, k)
   end
end

function M.Poll()
   local self = {
      items = {},
      zmq_pollitems = nil,
      changed = false,
   }
   return setmetatable(self, Poll_mt)
end

M.error = zmq_error

return M
