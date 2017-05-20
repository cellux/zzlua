local ffi = require('ffi')
local adt = require('adt')
local sdl = require('sdl2')
local util = require('util')
local sched = require('sched')
local trigger = require('trigger')

ffi.cdef [[

typedef int (*zz_audio_cb) (void *userdata,
                            float *stream,
                            int frames);

struct zz_audio_Source {
  zz_audio_cb callback;
  void *userdata;
  struct zz_audio_Source *next;
};

void zz_audio_Engine_cb(void *userdata, float *stream, int len);

struct zz_audio_Mixer {
  struct zz_audio_Source src;
  SDL_mutex *mutex;
  float *buf;
};

int zz_audio_Mixer_cb (void *userdata, float *stream, int frames);

struct zz_audio_SamplePlayer {
  struct zz_audio_Source src;
  float *buf;
  int frames;
  int channels;
  int pos;
  int playing;
  zz_trigger end_signal;
};

int zz_audio_SamplePlayer_cb (void *userdata, float *stream, int frames);

]]

local M = {}

function M.driver()
   return sdl.GetCurrentAudioDriver()
end

function M.devices()
   local count = sdl.GetNumAudioDevices()
   local index = 1
   local function _next()
      if index <= count then
         local device = {
            id = index,
            name = sdl.GetAudioDeviceName(index)
         }
         index = index + 1
         return device
      end
   end
   return _next
end

-- Source

local function Source(ct, cb, userdata)
   -- ct must be a struct type whose first member
   -- is a struct zz_audio_Source named `src`
   local source = ffi.new(ct)
   source.src.callback = cb
   source.src.userdata = userdata or source
   source.src.next = nil
   return source
end

M.Source = Source

-- Mixer

local Mixer_mt = {}

function Mixer_mt:setup(stream_buffer_size)
   self.mixer.buf = ffi.C.malloc(stream_buffer_size)
end

function Mixer_mt:lock()
   util.check_ok("SDL_LockMutex", 0, sdl.SDL_LockMutex(self.mixer.mutex))
end

function Mixer_mt:unlock()
   util.check_ok("SDL_UnlockMutex", 0, sdl.SDL_UnlockMutex(self.mixer.mutex))
end

function Mixer_mt:add(source)
   assert(type(source)=="table")
   assert(type(source.src)=="cdata")
   assert(not self.sources:contains(source))
   local src = ffi.cast("struct zz_audio_Source *", source.src)
   self:lock()
   src.next = self.src.next
   self.src.next = src
   self:unlock()
   self.sources:push(source)
end

function Mixer_mt:remove(source)
   assert(type(source)=="table")
   assert(type(source.src)=="cdata")
   assert(self.sources:contains(source))
   local src = ffi.cast("struct zz_audio_Source *", source.src)
   local cur = self.src
   while cur.next ~= nil do
      if cur.next == src then
         self:lock()
         cur.next = src.next
         src.next = nil
         self:unlock()
         break
      end
      cur = cur.next
   end
   self.sources:remove(source)
end

function Mixer_mt:clear()
   self:lock()
   self.src.next = nil
   self:unlock()
   self.sources:clear()
end

function Mixer_mt:delete()
   if self.mixer.mutex ~= nil then
      sdl.SDL_DestroyMutex(self.mixer.mutex)
      self.mixer.mutex = nil
   end
   if self.mixer.buf ~= nil then
      ffi.C.free(self.mixer.buf)
      self.mixer.buf = nil
   end
   self.src.next = nil
   self.sources:clear()
end

Mixer_mt.__index = Mixer_mt

local function Mixer()
   local mixer = Source("struct zz_audio_Mixer", ffi.C.zz_audio_Mixer_cb)
   mixer.mutex = sdl.SDL_CreateMutex()
   if mixer.mutex == nil then
      ef("SDL_CreateMutex() failed")
   end
   mixer.buf = nil
   local self = {
      mixer = mixer,
      src = mixer.src,
      sources = adt.Set(),
   }
   return setmetatable(self, Mixer_mt)
end

M.Mixer = Mixer

-- Engine

local Engine_mt = {}

function Engine_mt:add(source)
   self.mixer:add(source)
end

function Engine_mt:remove(source)
   self.mixer:remove(source)
end

function Engine_mt:clear()
   self.mixer:clear()
end

function Engine_mt:start()
   self.dev:start()
end

function Engine_mt:stop()
   self.dev:stop()
end

function Engine_mt:delete()
   self:stop()
   self:clear()
   self.mixer:delete()
   self.dev:close()
end

Engine_mt.__index = Engine_mt

local function Engine(opts)
   opts = opts or {}
   opts.format = sdl.AUDIO_F32
   opts.channels = 2
   opts.callback = ffi.C.zz_audio_Engine_cb
   local mixer = Mixer()
   opts.userdata = mixer.src
   local dev, spec = sdl.OpenAudioDevice(opts)
   mixer:setup(spec.size)
   local self = {
      dev = dev,
      mixer = mixer,
   }
   return setmetatable(self, Engine_mt), spec
end

M.Engine = Engine

-- SamplePlayer

local SamplePlayer_mt = {}

function SamplePlayer_mt:playing(state)
   if state then
      self.player.playing = state
   end
   return self.player.playing
end

function SamplePlayer_mt:play()
   self:playing(1)
   return self.end_signal -- caller may poll it if needed
end

function SamplePlayer_mt:pause()
   self:playing(0)
end

function SamplePlayer_mt:lseek(offset, whence)
   local new_pos
   if whence == ffi.C.SEEK_CUR then
      new_pos = self.player.pos + offset
   elseif whence == ffi.C.SEEK_SET then
      new_pos = offset
   elseif whence == ffi.C.SEEK_END then
      new_pos = self.player.frames - offset
   end
   if new_pos >= 0 and new_pos <= self.player.frames then
      -- TODO: this should be atomic
      self.player.pos = new_pos
   end
end

function SamplePlayer_mt:seek(offset, relative)
   if relative then
      self:lseek(offset, ffi.C.SEEK_CUR)
   elseif offset >= 0 then
      self:lseek(offset, ffi.C.SEEK_SET)
   else
      self:lseek(offset, ffi.C.SEEK_END)
   end
end

function SamplePlayer_mt:delete()
   self.end_signal:delete()
end

SamplePlayer_mt.__index = SamplePlayer_mt

function M.SamplePlayer(opts)
   opts = opts or {}
   local player = Source("struct zz_audio_SamplePlayer", ffi.C.zz_audio_SamplePlayer_cb)
   player.buf = opts.buf
   player.frames = opts.frames
   player.channels = opts.channels
   player.pos = 0
   player.playing = 0
   local end_signal = trigger()
   player.end_signal = end_signal
   local self = {
      player = player,
      src = player.src,
      buf = opts.buf, -- keep a reference to prevent GC
      frames = tonumber(opts.frames),
      channels = opts.channels,
      end_signal = end_signal,
   }
   return setmetatable(self, SamplePlayer_mt)
end

return M
