local ffi = require('ffi')
local sf = string.format
local util = require('util')

ffi.cdef [[

/* sys/socket.h */

typedef unsigned short int sa_family_t;

struct sockaddr {
  sa_family_t sa_family;
  char sa_data[14];
};

typedef uint32_t socklen_t;

struct sockaddr_un {
  sa_family_t sun_family;
  char sun_path[108]; /* Path name. */
};

typedef uint32_t in_addr_t;

static const in_addr_t INADDR_ANY       = ((in_addr_t) 0x00000000);
static const in_addr_t INADDR_BROADCAST = ((in_addr_t) 0xffffffff);
static const in_addr_t INADDR_LOOPBACK  = ((in_addr_t) 0x7f000001);
static const in_addr_t INADDR_NONE      = ((in_addr_t) 0xffffffff);

struct in_addr {
  in_addr_t s_addr;
};

typedef uint16_t in_port_t;

/* Ports less than this value are reserved for privileged processes. */
static const in_port_t IPPORT_RESERVED = 1024;

/* Ports greater this value are reserved for non-privileged servers. */
static const in_port_t IPPORT_USERRESERVED = 5000;

struct sockaddr_in {
  sa_family_t sin_family;
  in_port_t sin_port;       /* Port number.  */
  struct in_addr sin_addr;  /* Internet address.  */

  /* Pad to size of `struct sockaddr'.  */
  unsigned char sin_zero[sizeof (struct sockaddr) -
                         sizeof (sa_family_t) -
                         sizeof (in_port_t) -
                         sizeof (struct in_addr)];
};

enum {
  SHUT_RD = 0,
  SHUT_WR,
  SHUT_RDWR
};

enum socket_type
{
  SOCK_STREAM    = 1,		  /* Sequenced, reliable, connection-based
				                     byte streams.  */
  SOCK_DGRAM     = 2,		  /* Connectionless, unreliable datagrams
				                     of fixed maximum length.  */
  SOCK_RAW       = 3,			/* Raw protocol interface.  */
  SOCK_RDM       = 4,			/* Reliably-delivered messages.  */
  SOCK_SEQPACKET = 5,		  /* Sequenced, reliable, connection-based,
				                     datagrams of fixed maximum length.  */
  SOCK_DCCP      = 6,		  /* Datagram Congestion Control Protocol.  */
  SOCK_PACKET    = 10,		/* Linux specific way of getting packets
				                     at the dev level.  For writing rarp and
				                     other similar things on the user level. */

  /* Flags to be ORed into the type parameter of socket and socketpair
     and used for the flags parameter of paccept. */

  SOCK_CLOEXEC = 02000000, /* Atomically set close-on-exec flag for
				                      the new descriptor(s). */
  SOCK_NONBLOCK = 00004000 /* Atomically mark descriptor(s) as
				                      non-blocking. */
};

/* protocol family = domain = namespace */

enum {
  PF_UNSPEC = 0,
  PF_LOCAL = 1,
  PF_INET = 2,
  PF_MAX = 41
};

/* address family */

enum {
  AF_UNSPEC = PF_UNSPEC,
  AF_LOCAL = PF_LOCAL,
  AF_INET = PF_INET,
  AF_MAX = PF_MAX
};

/* socket levels */

static const int SOL_SOCKET = 1;

/* setsockopt / getsockopt options */

enum {
  SO_DEBUG      = 1,
  SO_REUSEADDR  = 2,
  SO_TYPE       = 3,
  SO_ERROR      = 4,
  SO_DONTROUTE  = 5,
  SO_BROADCAST  = 6,
  SO_SNDBUF     = 7,
  SO_RCVBUF     = 8,
  SO_KEEPALIVE  = 9,
  SO_OOBINLINKE = 10,
  SO_NO_CHECK   = 11,
  SO_PRIORITY   = 12,
  SO_LINGER     = 13,
  SO_BSDCOMPAT  = 14,
  SO_REUSEPORT  = 15,
  SO_PASSCRED   = 16,
  SO_PEERCRED   = 17,
  SO_RCVLOWAT   = 18,
  SO_SNDLOWAT   = 19,
  SO_RCVTIMEO   = 20,
  SO_SNDTIMEO   = 21
};

uint32_t ntohl (uint32_t netlong);
uint16_t ntohs (uint16_t netshort);
uint32_t htonl (uint32_t hostlong);
uint16_t htons (uint16_t hostshort);

const char *inet_ntop (int af,
                       const void *cp, char *buf, socklen_t len);
int inet_pton (int af,
               const char *cp, void *buf);

int socket (int domain, int type, int protocol);
int socketpair (int domain, int type, int protocol, int fds[2]);
int bind (int fd, const struct sockaddr * addr, socklen_t len);
int getsockname (int fd, struct sockaddr * addr, socklen_t * len);
int connect (int fd, const struct sockaddr * addr, socklen_t len);
int getpeername (int fd, struct sockaddr * addr, socklen_t * len);
ssize_t read (int fd, void *buf, size_t n);
ssize_t write (int fd, const void *buf, size_t n);
ssize_t recv (int fd, void *buf, size_t n, int flags);
ssize_t send (int fd, const void *buf, size_t n, int flags);
ssize_t recvfrom (int fd, void *buf, size_t n, int flags, struct sockaddr *address, socklen_t *address_len);
ssize_t sendto (int fd, const void *buf, size_t n, int flags, const struct sockaddr *dest_addr, socklen_t dest_len);
int getsockopt (int fd, int level, int optname, void * optval, socklen_t * optlen);
int setsockopt (int fd, int level, int optname, const void *optval, socklen_t optlen);
int listen (int fd, int n);
int accept (int fd, struct sockaddr * addr, socklen_t * len);
int close (int fd);
int shutdown (int fd, int how);

/* netdb.h */

struct hostent {
  char *h_name;       /* Official name of host.  */
  char **h_aliases;   /* Alias list.  */
  int h_addrtype;     /* Host address type.  */
  int h_length;       /* Length of address.  */
  char **h_addr_list; /* List of addresses from name server.  */
};

enum {
  HOST_NOT_FOUND = 1,
  TRY_AGAIN      = 2,
  NO_RECOVERY    = 3,
  NO_DATA        = 4
};

int gethostbyaddr_r (const void *addr, socklen_t len, int type,
			               struct hostent *result_buf,
			               char *buf, size_t buflen,
			               struct hostent **result,
			               int *h_errnop);

int gethostbyname_r (const char *name,
			               struct hostent *result_buf,
			               char *buf, size_t buflen,
			               struct hostent **result,
			               int *h_errnop);

]]

local sockaddr_mt = {}

function sockaddr_mt:__index(k)
   if k == "address" then
      if self.af == ffi.C.AF_LOCAL then
         local sun_path_offset = ffi.offsetof("struct sockaddr_un", "sun_path")
         local sun_path_len = self.addr_size - sun_path_offset
         local rv = ffi.string(self.addr.sun_path, sun_path_len)
         -- if the string contains a zero-terminator, strip it off
         if sun_path_len > 0 and rv:byte(sun_path_len) == 0 then
            rv = rv:sub(1, sun_path_len-1)
         end
         return rv
      elseif self.af == ffi.C.AF_INET then
         local bufsize = 128
         local buf = ffi.new("char[?]", bufsize)
         local rv = util.check_bad("inet_ntop", nil, ffi.C.inet_ntop(self.af, ffi.cast("const void *", self.addr.sin_addr), buf, bufsize))
         return ffi.string(rv)
      else
         error("Unsupported address family")
      end
   elseif k == "port" then
      if self.af == ffi.C.AF_INET then
         return ffi.C.ntohs(self.addr.sin_port)
      else
         error(sf("socket address with address family %u has no port", self.af))
      end
   else
      return rawget(self, k)
   end
end

local function sockaddr(af, address, port)
   local self = { af = af }
   if af == ffi.C.AF_LOCAL then
      address = address or ""
      if #address > 107 then
         error(sf("address too long: %s", address))
      end
      self.addr = ffi.new("struct sockaddr_un")
      self.addr.sun_family = ffi.C.AF_LOCAL
      ffi.copy(self.addr.sun_path, address)
      -- "You should compute the LENGTH parameter for a socket address
      -- in the local namespace as the sum of the size of the
      -- 'sun_family' component and the string length (_not_ the
      -- allocation size!)  of the file name string."
      self.addr_size = ffi.offsetof("struct sockaddr_un", "sun_path") + #address
   elseif af == ffi.C.AF_INET then
      address = address or "0.0.0.0"
      port = port or 0
      assert(type(port) == "number" and port >= 0 and port <= 65535)
      self.addr = ffi.new("struct sockaddr_in")
      self.addr.sin_family = ffi.C.AF_INET
      self.addr.sin_port = ffi.C.htons(port)
      util.check_ok("inet_pton", 1, ffi.C.inet_pton(ffi.C.AF_INET, address, self.addr.sin_addr))
      self.addr_size = ffi.sizeof("struct sockaddr_in")
   else
      error(sf("Unsupported address family: %u", af))
   end
   return setmetatable(self, sockaddr_mt)
end

local Socket_mt = {}

local function Socket(fd, domain)
   local self = {
      fd = fd,
      domain = domain,
      readbuf = ""
   }
   return setmetatable(self, Socket_mt)
end

function Socket_mt:bind(sockaddr)
   return util.check_bad("bind", -1, ffi.C.bind(self.fd, ffi.cast("struct sockaddr *", sockaddr.addr), sockaddr.addr_size))
end

function Socket_mt:listen(n)
   n = n or 16
   return util.check_bad("listen", -1, ffi.C.listen(self.fd, n))
end

function Socket_mt:getsockname()
   if self.domain == ffi.C.PF_LOCAL then
      error("getsockname() not supported for local sockets")
   end
   local sock_addr = sockaddr(self.domain)
   local sock_addr_size = ffi.new("socklen_t[1]", ffi.sizeof(sock_addr.addr))
   util.check_bad("getsockname", -1, ffi.C.getsockname(self.fd, ffi.cast("struct sockaddr *", sock_addr.addr), sock_addr_size))
   sock_addr.addr_size = sock_addr_size[0]
   return sock_addr
end

function Socket_mt:getpeername()
   if self.domain == ffi.C.PF_LOCAL then
      error("getpeername() not supported for local sockets")
   end
   local peer_addr = sockaddr(self.domain)
   local peer_addr_size = ffi.new("socklen_t[1]", ffi.sizeof(peer_addr.addr))
   util.check_bad("getpeername", -1, ffi.C.getpeername(self.fd, ffi.cast("struct sockaddr *", peer_addr.addr), peer_addr_size))
   peer_addr.addr_size = peer_addr_size[0]
   return peer_addr
end

function Socket_mt:accept()
   local client_fd = util.check_bad("accept", -1, ffi.C.accept(self.fd, nil, nil))
   return Socket(client_fd, self.domain)
end

function Socket_mt:connect(sockaddr)
   return util.check_bad("connect", -1, ffi.C.connect(self.fd, ffi.cast("struct sockaddr *", sockaddr.addr), sockaddr.addr_size))
end

function Socket_mt:read(size)
   local data = ""
   local remaining = size
   if remaining then
      assert(type(remaining)=="number" and remaining >= 0)
   end
   if #self.readbuf > 0 then
      if remaining then
         if #self.readbuf >= remaining then
            data = string.sub(self.readbuf, 1, remaining)
            self.readbuf = string.sub(self.readbuf, remaining+1)
            remaining = 0
            return data
         else
            data = self.readbuf
            self.readbuf = ""
            remaining = remaining - #data
         end
      else
         data = self.readbuf
         self.readbuf = ""
      end
   end
   local blocksize = 4096
   local buf = ffi.new("uint8_t[?]", blocksize)
   while true do
      if remaining then
         if remaining == 0 then
            break
         elseif remaining < blocksize then
            blocksize = remaining
         end
      end
      local nbytes = util.check_bad("read", -1, ffi.C.read(self.fd, buf, blocksize))
      if nbytes == 0 then
         break
      else
         data = data .. ffi.string(buf, nbytes)
      end
      if remaining then
         remaining = remaining - nbytes
      end
   end
   return data
end

function Socket_mt:readline()
   local blocksize = 4096
   local buf = ffi.new("uint8_t[?]", blocksize)
   while true do
      if #self.readbuf > 0 then
         local nlpos = string.find(self.readbuf, "\n", 1, true)
         if nlpos then
            local line = string.sub(self.readbuf, 1, nlpos-1)
            self.readbuf = string.sub(self.readbuf, nlpos+1)
            return line
         end
      end
      local nbytes = util.check_bad("read", -1, ffi.C.read(self.fd, buf, blocksize))
      if nbytes == 0 then
         -- if self.readbuf is not empty, then the last line of the
         -- file was not terminated by a new-line character
         return #self.readbuf > 0 and self.readbuf or nil
      else
         self.readbuf = self.readbuf .. ffi.string(buf, nbytes)
      end
   end
end

function Socket_mt:write(data)
   local nbytes = util.check_bad("write", -1, ffi.C.write(self.fd, data, #data))
   return nbytes
end

function Socket_mt:sendto(data, addr)
   local rv = util.check_bad("sendto", -1, ffi.C.sendto(self.fd, data, #data, 0, ffi.cast("const struct sockaddr *", addr.addr), addr.addr_size))
   return rv
end

function Socket_mt:recvfrom(buf)
   local bufsize
   if not buf then
      bufsize = 4096
      buf = ffi.new("uint8_t[?]", bufsize)
   else
      bufsize = #buf
   end
   local peer_addr = sockaddr(self.domain)
   local address_len = ffi.new("socklen_t[1]", ffi.sizeof(peer_addr.addr))
   local nbytes = util.check_bad("recvfrom", -1, ffi.C.recvfrom(self.fd, buf, bufsize, 0, ffi.cast("struct sockaddr *", peer_addr.addr), address_len))
   peer_addr.addr_size = address_len[0]
   return ffi.string(buf, nbytes), peer_addr
end

function Socket_mt:shutdown(how)
   return ffi.C.shutdown(self.fd, how)
end

function Socket_mt:close()
   local rv = 0
   -- double close is a noop
   if self.fd ~= 0 then
      rv = ffi.C.close(self.fd)
      self.fd = 0
   end
   return rv
end

Socket_mt.__newindex = function(self, k, v)
   if k == "SO_REUSEADDR" then
      local optval = ffi.new("int[1]", v and 1 or 0)
      ffi.C.setsockopt(self.fd,
                       ffi.C.SOL_SOCKET,
                       ffi.C.SO_REUSEADDR,
                       optval,
                       ffi.sizeof("int"))
   else
      error(sf("invalid attempt to set field on socket: %s", k))
   end
end

Socket_mt.__index = Socket_mt
Socket_mt.__gc = Socket_mt.close

local M = {}

M.sockaddr = sockaddr

function M.socket(domain, type, protocol)
   local fd = util.check_bad("socket", -1, ffi.C.socket(domain, type, protocol or 0))
   return Socket(fd, domain)
end

function M.socketpair(domain, type, protocol)
   local fds = ffi.new("int[2]")
   local rv = util.check_bad("socketpair", -1, ffi.C.socketpair(domain, type, protocol or 0, fds))
   return Socket(fds[0], domain), Socket(fds[1], domain)
end

local M_mt = {
   __index = ffi.C,
   __call = function(self, ...)
      return M.socket(...)
   end,
}

return setmetatable(M, M_mt)
