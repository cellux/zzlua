local ffi = require("ffi")

ffi.cdef [[

typedef uint32_t            jack_nframes_t;
typedef uint64_t            jack_time_t;
typedef struct _jack_port   jack_port_t;
typedef struct _jack_client jack_client_t;
typedef uint32_t            jack_port_id_t;
typedef float               jack_default_audio_sample_t;
typedef unsigned char       jack_midi_data_t;
typedef uint64_t            jack_unique_t;

enum JackOptions {
  JackNullOption    = 0x00,
  JackNoStartServer = 0x01,
  JackUseExactName  = 0x02,
  JackServerName    = 0x04,
  JackLoadName      = 0x08,
  JackLoadInit      = 0x10,
  JackSessionID     = 0x20
};

typedef enum JackOptions jack_options_t;

enum JackStatus {
  JackFailure       = 0x01,
  JackInvalidOption = 0x02,
  JackNameNotUnique = 0x04,
  JackServerStarted = 0x08,
  JackServerFailed  = 0x10,
  JackServerError   = 0x20,
  JackNoSuchClient  = 0x40,
  JackLoadFailure   = 0x80,
  JackInitFailure   = 0x100,
  JackShmFailure    = 0x200,
  JackVersionError  = 0x400,
  JackBackendError  = 0x800,
  JackClientZombie  = 0x1000
};

typedef enum JackStatus jack_status_t;

enum JackPortFlags {
  JackPortIsInput    = 0x1,
  JackPortIsOutput   = 0x2,
  JackPortIsPhysical = 0x4,
  JackPortCanMonitor = 0x8,
  JackPortIsTerminal = 0x10,
};

typedef enum {
  JackTransportStopped     = 0, /**< Transport halted */
  JackTransportRolling     = 1, /**< Transport playing */
  JackTransportLooping     = 2, /**< For OLD_TRANSPORT, now ignored */
  JackTransportStarting    = 3, /**< Waiting for sync ready */
  JackTransportNetStarting = 4, /**< Waiting for sync ready on the network*/
} jack_transport_state_t;

typedef enum {
  JackPositionBBT      = 0x10, /**< Bar, Beat, Tick */
  JackPositionTimecode = 0x20, /**< External timecode */
  JackBBTFrameOffset   = 0x40, /**< Frame offset of BBT information */
  JackAudioVideoRatio  = 0x80, /**< audio frames per video frame */
  JackVideoFrameOffset = 0x100 /**< frame offset of first video frame */
} jack_position_bits_t;

typedef struct {
  jack_unique_t       unique_1;       /**< unique ID */
  jack_time_t         usecs;          /**< monotonic, free-rolling */
  jack_nframes_t      frame_rate;     /**< current frame rate (per second) */
  jack_nframes_t      frame;          /**< frame number, always present */
  jack_position_bits_t valid;         /**< which other fields are valid */
  int32_t             bar;            /**< current bar */
  int32_t             beat;           /**< current beat-within-bar */
  int32_t             tick;           /**< current tick-within-beat */
  double              bar_start_tick;
  float               beats_per_bar;  /**< time signature "numerator" */
  float               beat_type;      /**< time signature "denominator" */
  double              ticks_per_beat;
  double              beats_per_minute;
  double              frame_time;     /**< current time in seconds */
  double              next_time;      /**< next sequential frame_time */
  jack_nframes_t      bbt_offset;     /**< frame offset for the BBT fields */
  float               audio_frames_per_video_frame;
  jack_nframes_t      video_offset;
  int32_t             padding[7];
  jack_unique_t       unique_2;       /**< unique ID */
} jack_position_t;

typedef struct _jack_midi_event
{
  jack_nframes_t    time;   /**< Sample index at which event is valid */
  size_t            size;   /**< Number of bytes of data in a buffer */
  jack_midi_data_t *buffer; /**< Raw MIDI data */
} jack_midi_event_t;

/* callback types */

typedef int  (*JackProcessCallback) (jack_nframes_t nframes,
                                     void *arg);
typedef void (*JackThreadInitCallback) (void *arg);
typedef int  (*JackXRunCallback) (void *arg);
typedef int  (*JackBufferSizeCallback) (jack_nframes_t nframes,
                                        void *arg);
typedef int  (*JackSampleRateCallback) (jack_nframes_t nframes,
                                        void *arg);
typedef void (*JackPortRegistrationCallback) (jack_port_id_t port,
                                              int register,
                                              void *arg);
typedef void (*JackClientRegistrationCallback) (const char* name,
                                                int register,
                                                void *arg);
typedef void (*JackPortConnectCallback) (jack_port_id_t a,
                                         jack_port_id_t b,
                                         int connect,
                                         void* arg);
typedef int  (*JackPortRenameCallback) (jack_port_id_t port,
                                        const char* old_name,
                                        const char* new_name,
                                        void *arg);
typedef void (*JackFreewheelCallback) (int starting,
                                       void *arg);
typedef void (*JackInfoShutdownCallback) (jack_status_t code,
                                          const char* reason,
                                          void *arg);
typedef int  (*JackSyncCallback) (jack_transport_state_t state,
                                  jack_position_t *pos,
                                  void *arg);
typedef void (*JackTimebaseCallback) (jack_transport_state_t state,
                                      jack_nframes_t nframes,
                                      jack_position_t *pos,
                                      int new_pos,
                                      void *arg);

/* main API */

jack_client_t *jack_client_open (const char *client_name,
                                 jack_options_t options,
                                 jack_status_t *status, ...);
int            jack_client_name_size (void);
char *         jack_get_client_name (jack_client_t *client);
int            jack_activate (jack_client_t *client);
int            jack_deactivate (jack_client_t *client);
int            jack_get_client_pid (const char *name);
int            jack_is_realtime (jack_client_t *client);
int            jack_set_freewheel (jack_client_t* client, int onoff);
int            jack_set_buffer_size (jack_client_t *client, jack_nframes_t nframes);
jack_nframes_t jack_get_buffer_size (jack_client_t *);
jack_nframes_t jack_get_sample_rate (jack_client_t *);
float          jack_cpu_load (jack_client_t *client);
int            jack_client_close (jack_client_t *client);

/* port API */

jack_port_t * jack_port_register (jack_client_t *client,
                                  const char *port_name,
                                  const char *port_type,
                                  unsigned long flags,
                                  unsigned long buffer_size);
int           jack_port_unregister (jack_client_t *,
                                    jack_port_t *);
void *        jack_port_get_buffer (jack_port_t *,
                                    jack_nframes_t);
const char *  jack_port_name (const jack_port_t *port);
const char *  jack_port_short_name (const jack_port_t *port);
int           jack_port_flags (const jack_port_t *port);
const char *  jack_port_type (const jack_port_t *port);
int           jack_port_is_mine (const jack_client_t *,
                                 const jack_port_t *port);
int           jack_port_connected (const jack_port_t *port);
int           jack_port_connected_to (const jack_port_t *port,
                                      const char *port_name);
int           jack_port_set_name (jack_port_t *port,
                                  const char *port_name);
int           jack_port_set_alias (jack_port_t *port,
                                   const char *alias);
int           jack_port_unset_alias (jack_port_t *port,
                                     const char *alias);
int           jack_port_get_aliases (const jack_port_t *port,
                                     char* const aliases[2]);
int           jack_connect (jack_client_t *,
                            const char *source_port,
                            const char *destination_port);
int           jack_disconnect (jack_client_t *,
                               const char *source_port,
                               const char *destination_port);
int           jack_port_disconnect (jack_client_t *,
                                    jack_port_t *);
int           jack_port_name_size (void);
int           jack_port_type_size (void);
jack_port_t * jack_port_by_name (jack_client_t *,
                                 const char *port_name);
jack_port_t * jack_port_by_id (jack_client_t *client,
                               jack_port_id_t port_id);

/* time API */

jack_nframes_t jack_frames_since_cycle_start (const jack_client_t *);
jack_nframes_t jack_frame_time (const jack_client_t *);
jack_time_t    jack_frames_to_time (const jack_client_t *client,
                                    jack_nframes_t);
jack_nframes_t jack_time_to_frames (const jack_client_t *client,
                                    jack_time_t);
jack_time_t    jack_get_time ();

/* error handling */

typedef void (*jack_error_callback) (const char *msg);
typedef void (*jack_info_callback) (const char *msg);

void jack_set_error_function (jack_error_callback error_callback);
void jack_set_info_function (jack_info_callback info_callback);

/* callback API */

int  jack_set_process_callback (jack_client_t *client,
                                JackProcessCallback process_callback,
                                void *arg);
int  jack_set_thread_init_callback (jack_client_t *client,
                                    JackThreadInitCallback thread_init_callback,
                                    void *arg);
void jack_on_info_shutdown (jack_client_t *client,
                            JackInfoShutdownCallback shutdown_callback,
                            void *arg);
int  jack_set_freewheel_callback (jack_client_t *client,
                                  JackFreewheelCallback freewheel_callback,
                                  void *arg);
int  jack_set_buffer_size_callback (jack_client_t *client,
                                    JackBufferSizeCallback bufsize_callback,
                                    void *arg);
int  jack_set_sample_rate_callback (jack_client_t *client,
                                    JackSampleRateCallback srate_callback,
                                    void *arg);
int  jack_set_client_registration_callback (jack_client_t *,
                                            JackClientRegistrationCallback registration_callback,
                                            void *arg);
int  jack_set_port_registration_callback (jack_client_t *,
                                          JackPortRegistrationCallback registration_callback,
                                          void *arg);
int  jack_set_port_connect_callback (jack_client_t *,
                                     JackPortConnectCallback connect_callback,
                                     void *arg);
int  jack_set_port_rename_callback (jack_client_t *,
                                    JackPortRenameCallback rename_callback,
                                    void *arg);
int  jack_set_xrun_callback (jack_client_t *,
                             JackXRunCallback xrun_callback,
                             void *arg);

/* midi API */

uint32_t          jack_midi_get_event_count (void* port_buffer);
int               jack_midi_event_get (jack_midi_event_t *event,
                                       void *port_buffer,
                                       uint32_t event_index);
void              jack_midi_clear_buffer (void *port_buffer);
size_t            jack_midi_max_event_size (void* port_buffer);
jack_midi_data_t* jack_midi_event_reserve (void *port_buffer,
                                           jack_nframes_t time,
                                           size_t data_size);
int               jack_midi_event_write (void *port_buffer,
                                         jack_nframes_t time,
                                         const jack_midi_data_t *data,
                                         size_t data_size);
uint32_t          jack_midi_get_lost_event_count (void *port_buffer);

/* Jack ringbuffer implementation */

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
void   jack_ringbuffer_free(jack_ringbuffer_t *rb);
void   jack_ringbuffer_get_read_vector(const jack_ringbuffer_t *rb,
                                       jack_ringbuffer_data_t *vec);
void   jack_ringbuffer_get_write_vector(const jack_ringbuffer_t *rb,
                                        jack_ringbuffer_data_t *vec);
size_t jack_ringbuffer_read(jack_ringbuffer_t *rb, char *dest, size_t cnt);
size_t jack_ringbuffer_peek(jack_ringbuffer_t *rb, char *dest, size_t cnt);
void   jack_ringbuffer_read_advance(jack_ringbuffer_t *rb, size_t cnt);
size_t jack_ringbuffer_read_space(const jack_ringbuffer_t *rb);
int    jack_ringbuffer_mlock(jack_ringbuffer_t *rb);
void   jack_ringbuffer_reset(jack_ringbuffer_t *rb);
size_t jack_ringbuffer_write(jack_ringbuffer_t *rb, const char *src, size_t cnt);
void   jack_ringbuffer_write_advance(jack_ringbuffer_t *rb, size_t cnt);
size_t jack_ringbuffer_write_space(const jack_ringbuffer_t *rb);

/* Lua ctype for Jack client objects */

struct jack_client_ct {
  jack_client_t *client;
};

]]

local jack = ffi.load("jack")

local g_midi_rb -- midi ringbuffer
local g_client -- client instance

local M = {}

M.JACK_DEFAULT_AUDIO_TYPE = "32 bit float mono audio"
M.JACK_DEFAULT_MIDI_TYPE  = "8 bit raw midi"

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
