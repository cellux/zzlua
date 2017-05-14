local ffi = require('ffi')
local adt = require('adt')
local sdl = require('sdl2')
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

struct zz_audio_Mixer {
  struct zz_audio_Source *next;
  float *buf;
};

void zz_audio_Mixer_cb (void *userdata, float *stream, int len);

struct zz_audio_Sample {
  struct zz_audio_Source src;
  float *buf;
  int frames;
  int channels;
  int pos;
  int playing;
  zz_trigger end_signal;
};

int zz_audio_Sample_cb (void *userdata, float *stream, int frames);

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

-- Mixer

local Mixer_mt = {}

function Mixer_mt:setup(spec)
   self.next = nil
   self.buf = ffi.C.malloc(spec.size)
end

function Mixer_mt:add(src)
   src = ffi.cast("struct zz_audio_Source *", src)
   src.next = self.next
   self.next = src
end

function Mixer_mt:remove(src)
   src = ffi.cast("struct zz_audio_Source *", src)
   local cur = self
   while cur.next ~= nil do
      if cur.next == src then
         cur.next = src.next
         src.next = nil
         break
      end
      cur = cur.next
   end
end

function Mixer_mt:remove_all()
   -- freeing the sources is not our responsibility
   self.next = nil
end

function Mixer_mt:delete()
   if self.buf ~= nil then
      ffi.C.free(self.buf)
      self.buf = nil
   end
   self.next = nil
end

Mixer_mt.__index = Mixer_mt
Mixer_mt.__gc = Mixer_mt.delete

local Mixer = ffi.metatype("struct zz_audio_Mixer", Mixer_mt)

-- Engine

local Engine_mt = {}

function Engine_mt:add(source)
   assert(type(source)=="table")
   assert(type(source.src)=="cdata")
   assert(not self.sources:contains(source))
   self.sources:push(source)
   if type(source.start)=="function" then
      source:start()
   end
   self.mixer:add(source.src)
end

function Engine_mt:remove(source)
   assert(type(source)=="table")
   assert(type(source.src)=="cdata")
   self.mixer:remove(source.src)
   if type(source.stop)=="function" then
      source:stop()
   end
   self.sources:remove(source)
end

function Engine_mt:remove_all()
   self.mixer:remove_all()
   for source in self.sources:iteritems() do
      if type(source.stop)=="function" then
         source:stop()
      end
   end
   self.sources:clear()
end

function Engine_mt:start()
   self.dev:start()
end

function Engine_mt:stop()
   self.dev:stop()
end

function Engine_mt:delete()
   self:stop()
   self:remove_all()
   self.mixer:delete()
   self.dev:close()
end

Engine_mt.__index = Engine_mt
Engine_mt.__gc = Engine_mt.delete

local function Engine(opts)
   opts = opts or {}
   opts.format = sdl.AUDIO_F32
   opts.channels = 2
   local mixer = Mixer()
   opts.callback = ffi.C.zz_audio_Mixer_cb
   opts.userdata = mixer
   local dev, spec = sdl.OpenAudioDevice(opts)
   mixer:setup(spec)
   local self = {
      dev = dev,
      mixer = mixer,
      sources = adt.Set(),
   }
   return setmetatable(self, Engine_mt), spec
end

M.Engine = Engine

-- generic audio source

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

-- Sample

local Sample_mt = {}

function Sample_mt:playing(state)
   if state then
      self.sample.playing = state
   end
   return self.sample.playing
end

function Sample_mt:play()
   self:playing(1)
   return self.end_signal -- caller may poll it if needed
end

function Sample_mt:pause()
   self:playing(0)
end

function Sample_mt:lseek(offset, whence)
   local new_pos
   if whence == ffi.C.SEEK_CUR then
      new_pos = self.sample.pos + offset
   elseif whence == ffi.C.SEEK_SET then
      new_pos = offset
   elseif whence == ffi.C.SEEK_END then
      new_pos = self.sample.frames - offset
   end
   if new_pos >= 0 and new_pos <= self.sample.frames then
      -- TODO: this should be atomic
      self.sample.pos = new_pos
   end
end

function Sample_mt:seek(offset, relative)
   if relative then
      self:lseek(offset, ffi.C.SEEK_CUR)
   elseif offset >= 0 then
      self:lseek(offset, ffi.C.SEEK_SET)
   else
      self:lseek(offset, ffi.C.SEEK_END)
   end
end

function Sample_mt:delete()
   self.end_signal:delete()
end

Sample_mt.__index = Sample_mt
Sample_mt.__gc = Sample_mt.delete

function M.Sample(opts)
   opts = opts or {}
   local sample = Source("struct zz_audio_Sample", ffi.C.zz_audio_Sample_cb)
   sample.buf = opts.buf
   sample.frames = opts.frames
   sample.channels = opts.channels
   sample.pos = 0
   sample.playing = 0
   local end_signal = trigger()
   sample.end_signal = end_signal
   local self = {
      sample = sample,
      src = sample.src,
      buf = opts.buf, -- keep a reference to prevent GC
      frames = tonumber(opts.frames),
      channels = opts.channels,
      end_signal = end_signal,
   }
   return setmetatable(self, Sample_mt)
end

return M
