local ffi = require("ffi")

ffi.cdef [[

typedef uint32_t jack_nframes_t;

enum JackOptions {
  JackNullOption = 0x00,
  JackNoStartServer = 0x01,
  JackUseExactName = 0x02,
  JackServerName = 0x04,
  JackLoadName = 0x08,
  JackLoadInit = 0x10,
  JackSessionID = 0x20
};

typedef enum JackOptions jack_options_t;

enum JackStatus {
  JackFailure = 0x01,
  JackInvalidOption = 0x02,
  JackNameNotUnique = 0x04,
  JackServerStarted = 0x08,
  JackServerFailed = 0x10,
  JackServerError = 0x20,
  JackNoSuchClient = 0x40,
  JackLoadFailure = 0x80,
  JackInitFailure = 0x100,
  JackShmFailure = 0x200,
  JackVersionError = 0x400,
  JackBackendError = 0x800,
  JackClientZombie = 0x1000
};

typedef enum JackStatus jack_status_t;

typedef struct _jack_client jack_client_t;
jack_client_t *jack_client_open (const char *client_name,
                                 jack_options_t options,
                                 jack_status_t *status, ...);
int jack_activate (jack_client_t *client);
int jack_deactivate (jack_client_t *client);
int jack_client_close (jack_client_t *client);

typedef int (*JackProcessCallback)(jack_nframes_t nframes, void *arg);
int jack_set_process_callback (jack_client_t *client,
                               JackProcessCallback process_callback,
                               void *arg);

struct jack_client_ct {
  jack_client_t *client;
};

typedef struct {
  char *buf;
  size_t len;
} jack_ringbuffer_data_t;

typedef struct {
  char *buf;
  volatile size_t write_ptr;
  volatile size_t read_ptr;
  size_t size;
  size_t size_mask;
  int mlocked;
} jack_ringbuffer_t;

jack_ringbuffer_t *jack_ringbuffer_create(size_t sz);
void jack_ringbuffer_free(jack_ringbuffer_t *rb);
void jack_ringbuffer_get_read_vector(const jack_ringbuffer_t *rb,
                                     jack_ringbuffer_data_t *vec);
void jack_ringbuffer_get_write_vector(const jack_ringbuffer_t *rb,
                                      jack_ringbuffer_data_t *vec);
size_t jack_ringbuffer_read(jack_ringbuffer_t *rb, char *dest, size_t cnt);
size_t jack_ringbuffer_peek(jack_ringbuffer_t *rb, char *dest, size_t cnt);
void jack_ringbuffer_read_advance(jack_ringbuffer_t *rb, size_t cnt);
size_t jack_ringbuffer_read_space(const jack_ringbuffer_t *rb);
int jack_ringbuffer_mlock(jack_ringbuffer_t *rb);
void jack_ringbuffer_reset(jack_ringbuffer_t *rb);
size_t jack_ringbuffer_write(jack_ringbuffer_t *rb, const char *src, size_t cnt);
void jack_ringbuffer_write_advance(jack_ringbuffer_t *rb, size_t cnt);
size_t jack_ringbuffer_write_space(const jack_ringbuffer_t *rb);

]]

local jack = ffi.load("jack")

local g_midi_rb -- midi ringbuffer
local g_client -- client instance

local M = {}

local Client_mt = {}

function Client_mt:close()
   return jack.jack_client_close(self.client)
end

function Client_mt:activate()
   return jack.jack_activate(self.client)
end

function Client_mt:deactivate()
   return jack.jack_deactivate(self.client)
end

Client_mt.__index = Client_mt

local Client_ct = ffi.metatype("struct jack_client_ct", Client_mt)

function M.open(client_name)
   if g_client then
      error("attempt to create two Jack clients (there can be only one)")
   end
   local options = jack.JackNoStartServer + jack.JackUseExactName
   local status = ffi.new("jack_status_t[1]")
   local client = jack.jack_client_open(client_name, options, status)
   if client ~= nil then
      g_client = Client_ct(client)
      g_midi_rb = jack.jack_ringbuffer_create(4096)
      assert(g_midi_rb, "jack_ringbuffer_create() failed")
   end
   return g_client, tonumber(status[0])
end

local function assert_client()
   assert(g_client, "you must create a jack client before invoking any jack functions")
end

function M.activate()
   assert_client()
   return g_client:activate()
end

function M.deactivate()
   assert_client()
   return g_client:deactivate()
end

function M.write_midi_bytes(...)
   assert_client()
   local bytes = {...}
   local len = #bytes
   local buf = ffi.new("uint8_t[?]", len)
   for i=1,len do
      buf[i-1] = bytes[i]
   end
   local bytes_written = jack.jack_ringbuffer_write(g_midi_rb, buf, len)
   if bytes_written ~= len then
      error("write error: jack midi ringbuffer is full")
   end
end

function M.close()
   assert_client()
   jack.jack_ringbuffer_free(g_midi_rb)
   g_midi_rb = nil
   local rv = g_client:close()
   g_client = nil
   return rv
end

return setmetatable(M, { __index = jack })
