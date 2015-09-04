local ffi = require('ffi')
local sched = require('sched')
local file = require('file')
local util = require('util')

ffi.cdef [[

typedef enum {
  SDL_FALSE = 0,
  SDL_TRUE = 1
} SDL_bool;

typedef int8_t   Sint8;
typedef uint8_t  Uint8;
typedef int16_t  Sint16;
typedef uint16_t Uint16;
typedef int32_t  Sint32;
typedef uint32_t Uint32;
typedef int64_t  Sint64;
typedef uint64_t Uint64;

typedef struct SDL_version {
  Uint8 major;        /**< major version */
  Uint8 minor;        /**< minor version */
  Uint8 patch;        /**< update version */
} SDL_version;

void SDL_GetVersion (SDL_version * ver);

const char * SDL_GetPlatform (void);
int SDL_GetSystemRAM (void);
int SDL_GetCPUCount (void);

enum {
  SDL_INIT_TIMER          = 0x00000001,
  SDL_INIT_AUDIO          = 0x00000010,
  SDL_INIT_VIDEO          = 0x00000020,
  SDL_INIT_JOYSTICK       = 0x00000200,
  SDL_INIT_HAPTIC         = 0x00001000,
  SDL_INIT_GAMECONTROLLER = 0x00002000,
  SDL_INIT_EVENTS         = 0x00004000,
  SDL_INIT_NOPARACHUTE    = 0x00100000,
  SDL_INIT_EVERYTHING     = ( SDL_INIT_TIMER    |
                              SDL_INIT_AUDIO    |
                              SDL_INIT_VIDEO    |
                              SDL_INIT_EVENTS   |
                              SDL_INIT_JOYSTICK |
                              SDL_INIT_HAPTIC   |
                              SDL_INIT_GAMECONTROLLER )
};

int SDL_Init (Uint32 flags);
int SDL_InitSubSystem (Uint32 flags);
void SDL_QuitSubSystem (Uint32 flags);
Uint32 SDL_WasInit (Uint32 flags);
void SDL_Quit(void);

typedef struct SDL_Window SDL_Window;

typedef enum {
  SDL_MESSAGEBOX_ERROR        = 0x00000010,   /**< error dialog */
  SDL_MESSAGEBOX_WARNING      = 0x00000020,   /**< warning dialog */
  SDL_MESSAGEBOX_INFORMATION  = 0x00000040    /**< informational dialog */
} SDL_MessageBoxFlags;

int SDL_ShowSimpleMessageBox(Uint32 flags,
                             const char *title,
                             const char *message,
                             SDL_Window *window);

]]

local sdl = ffi.load("SDL2")

local M = {}

function M.GetPlatform()
   return ffi.string(sdl.SDL_GetPlatform())
end

function M.GetSystemRAM()
   return sdl.SDL_GetSystemRAM()
end

function M.GetCPUCount()
   return sdl.SDL_GetCPUCount()
end

function M.GetVersion()
   local v = ffi.new("SDL_version")
   sdl.SDL_GetVersion(v)
   return v.major, v.minor, v.patch
end

M.initflags = sdl.SDL_INIT_AUDIO +
              sdl.SDL_INIT_VIDEO +
              sdl.SDL_INIT_EVENTS +
              sdl.SDL_INIT_NOPARACHUTE

local function SDL2Module(sched)
   local self = {}
   self.pollable_devices = {
      keyboard = {},
      mouse = {}
   }
   local function discover_pollable_devices()
      local input_dev_dir = "/sys/class/input"
      if file.is_dir(input_dev_dir) then
         for fn in file.readdir(input_dev_dir) do
            if fn:match("^event[0-9]$") then
               local devname_path = sf("%s/%s/device/name", input_dev_dir, fn)
               if file.exists(devname_path) then
                  local devname = file.read(devname_path, 256)
                  for name,_ in pairs(self.pollable_devices) do
                     if string.lower(devname):match(name) then
                        local devpath = sf("/dev/input/%s", fn)
                        -- these devices are only readable by root :(
                        --
                        -- which is understandable, otherwise users
                        -- could easily install keyloggers which steal
                        -- what is typed by other users including root
                        if file.is_readable(devpath) then
                           local dev = file.open(devpath)
                           table.insert(self.pollable_devices[name], dev)
                        else
                           -- in this case, we won't be able to poll
                           -- keyboard/mouse devices so events will be
                           -- collected at tick granularity. if you
                           -- want seamless event collection, you have
                           -- to ensure that the event loop does not
                           -- block for too long. one way to do this
                           -- is to run a thread which draws something
                           -- to the screen 60 times/second.
                        end
                     end
                  end
               end
            end
         end
      end
   end
   local function foreach_dev(fn)
      for name,device_files in pairs(self.pollable_devices) do
         for _,dev in ipairs(device_files) do
            fn(dev)
         end
      end
   end
   local function register_pollable_devices(event_id)
      foreach_dev(function(dev)
         sched.poller:add(dev.fd, "r", event_id)
      end)
   end
   local function unregister_pollable_devices(event_id)
      foreach_dev(function(dev)
         sched.poller:del(dev.fd, "r", event_id)
      end)
   end
   local function close_pollable_devices()
      foreach_dev(function(dev)
         dev:close()
      end)
   end
   local sdl_input_event = sched.make_event_id()
   function self.init()
      discover_pollable_devices()
      register_pollable_devices(sdl_input_event)
      util.check_ok("SDL_Init", 0, sdl.SDL_Init(M.initflags))
   end
   function self.done()
      sdl.SDL_Quit()
      unregister_pollable_devices(sdl_input_event)
      close_pollable_devices()
   end
   return self
end

sched.register_module(SDL2Module)

local M_mt = {
   __index = sdl
}

return setmetatable(M, M_mt)
