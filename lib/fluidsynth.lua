local ffi = require('ffi')
local util = require('util')
local audio = require('audio')

ffi.cdef [[

/* types.h */

typedef struct _fluid_hashtable_t fluid_settings_t;
typedef struct _fluid_synth_t fluid_synth_t;
typedef struct _fluid_synth_channel_info_t fluid_synth_channel_info_t;
typedef struct _fluid_sfont_t fluid_sfont_t;

/* misc.h */

enum {
  FLUID_OK = 0,
  FLUID_FAILED = -1
};

int fluid_is_soundfont(const char *filename);

/* settings.h */

fluid_settings_t* new_fluid_settings(void);
int fluid_settings_setstr(fluid_settings_t* settings,
                          const char *name,
                          const char *str);
int fluid_settings_getstr(fluid_settings_t* settings,
                          const char *name,
                          char** str);
int fluid_settings_setnum(fluid_settings_t* settings,
                          const char *name,
                          double val);
int fluid_settings_getnum(fluid_settings_t* settings,
                          const char *name,
                          double* val);
int fluid_settings_setint(fluid_settings_t* settings,
                          const char *name,
                          int val);
int fluid_settings_getint(fluid_settings_t* settings,
                          const char *name,
                          int *val);
void delete_fluid_settings(fluid_settings_t* settings);

/* synth.h */

fluid_synth_t* new_fluid_synth(fluid_settings_t* settings);

int fluid_synth_noteon(fluid_synth_t* synth, int chan, int key, int vel);
int fluid_synth_noteoff(fluid_synth_t* synth, int chan, int key);
int fluid_synth_cc(fluid_synth_t* synth, int chan, int ctrl, int val);
int fluid_synth_pitch_bend(fluid_synth_t* synth, int chan, int val);
int fluid_synth_pitch_wheel_sens(fluid_synth_t* synth, int chan, int val);
int fluid_synth_program_change(fluid_synth_t* synth, int chan, int program);
int fluid_synth_channel_pressure(fluid_synth_t* synth, int chan, int val);
int fluid_synth_bank_select(fluid_synth_t* synth, int chan, unsigned int bank);
int fluid_synth_sfont_select(fluid_synth_t* synth, int chan, unsigned int sfont_id);
int fluid_synth_program_select(fluid_synth_t* synth, int chan, unsigned int sfont_id, unsigned int bank_num, unsigned int preset_num);

static const int FLUID_SYNTH_CHANNEL_INFO_NAME_SIZE = 32;

typedef struct _fluid_synth_channel_info_t
{
  int assigned : 1;
  int sfont_id;
  int bank;
  int program;
  char name[FLUID_SYNTH_CHANNEL_INFO_NAME_SIZE];
  char reserved[32];
};

int fluid_synth_get_channel_info (fluid_synth_t *synth, int chan, fluid_synth_channel_info_t *info);

int fluid_synth_program_reset(fluid_synth_t* synth);
int fluid_synth_system_reset(fluid_synth_t* synth);
int fluid_synth_all_notes_off(fluid_synth_t* synth, int chan);
int fluid_synth_all_sounds_off(fluid_synth_t* synth, int chan);

enum fluid_midi_channel_type {
  CHANNEL_TYPE_MELODIC = 0,
  CHANNEL_TYPE_DRUM = 1
};

int fluid_synth_set_channel_type(fluid_synth_t* synth, int chan, int type);

int fluid_synth_sfload(fluid_synth_t* synth, const char* filename, int reset_presets);
int fluid_synth_sfreload(fluid_synth_t* synth, unsigned int id);
fluid_sfont_t* fluid_synth_get_sfont(fluid_synth_t* synth, unsigned int num);
fluid_sfont_t* fluid_synth_get_sfont_by_id(fluid_synth_t* synth, unsigned int id);
int fluid_synth_sfunload(fluid_synth_t* synth, unsigned int id, int reset_presets);

void fluid_synth_set_sample_rate(fluid_synth_t* synth, float sample_rate);
void fluid_synth_set_gain(fluid_synth_t* synth, float gain);
float fluid_synth_get_gain(fluid_synth_t* synth);
int fluid_synth_set_polyphony(fluid_synth_t* synth, int polyphony);
int fluid_synth_get_polyphony(fluid_synth_t* synth);
int fluid_synth_get_active_voice_count(fluid_synth_t* synth);
int fluid_synth_get_internal_bufsize(fluid_synth_t* synth);

double fluid_synth_get_cpu_load(fluid_synth_t* synth);
char* fluid_synth_error(fluid_synth_t* synth);

int fluid_synth_write_s16(fluid_synth_t* synth, int len,
				                  void* lout, int loff, int lincr, 
				                  void* rout, int roff, int rincr);
int fluid_synth_write_float(fluid_synth_t* synth, int len, 
					                  void* lout, int loff, int lincr, 
					                  void* rout, int roff, int rincr);
int fluid_synth_nwrite_float(fluid_synth_t* synth, int len, 
					                   float** left, float** right, 
					                   float** fx_left, float** fx_right);
int fluid_synth_process(fluid_synth_t* synth, int len,
				                int nin, float** in, 
				                int nout, float** out);

int delete_fluid_synth(fluid_synth_t* synth);

/* zz_fluidsynth */

struct zz_fluidsynth_settings {
  fluid_settings_t *settings;
};

struct zz_fluidsynth_synth {
  fluid_synth_t *synth;
};

struct zz_fluidsynth_audio_source {
  struct zz_audio_Source src;
};

int zz_fluidsynth_audio_callback(void *userdata, float *stream, int frames);

]]

local fluid = ffi.load("fluidsynth")

local M = {}

local Settings_mt = {}

function Settings_mt:setstr(name, str)
   fluid.fluid_settings_setstr(self.settings, name, str)
end

function Settings_mt:getstr(name)
   local str = ffi.new("char*[1]")
   fluid.fluid_settings_getstr(self.settings, name, str)
   return ffi.string(str[0])
end

function Settings_mt:setnum(name, val)
   fluid.fluid_settings_setnum(self.settings, name, val)
end

function Settings_mt:getnum(name)
   local val = ffi.new("double[1]")
   fluid.fluid_settings_getnum(self.settings, name, val)
   return tonumber(val[0])
end

function Settings_mt:setint(name, val)
   fluid.fluid_settings_setint(self.settings, name, val)
end

function Settings_mt:getint(name)
   local val = ffi.new("int[1]")
   fluid.fluid_settings_getint(self.settings, name, val)
   return tonumber(val[0])
end

function Settings_mt:delete()
   if self.settings ~= nil then
      fluid.delete_fluid_settings(self.settings)
      self.settings = nil
   end
end

Settings_mt.__index = Settings_mt
Settings_mt.__gc = Settings_mt.delete
local Settings = ffi.metatype("struct zz_fluidsynth_settings", Settings_mt)

function M.Settings()
   local settings = fluid.new_fluid_settings()
   return Settings(settings)
end

local Synth_mt = {}

function Synth_mt:noteon(chan, key, vel)
   fluid.fluid_synth_noteon(self.synth, chan, key, vel)
end

function Synth_mt:noteoff(chan, key)
   fluid.fluid_synth_noteoff(self.synth, chan, key)
end

function Synth_mt:cc(chan, ctrl, val)
   fluid.fluid_synth_cc(self.synth, chan, ctrl, val)
end

function Synth_mt:pitch_bend(chan, val)
   fluid.fluid_synth_pitch_bend(self.synth, chan, val)
end

function Synth_mt:pitch_wheel_sens(chan, val)
   fluid.fluid_synth_pitch_wheel_sens(self.synth, chan, val)
end

function Synth_mt:program_change(chan, program)
   fluid.fluid_synth_program_change(self.synth, chan, program)
end

function Synth_mt:channel_pressure(chan, val)
   fluid.fluid_synth_channel_pressure(self.synth, chan, val)
end

function Synth_mt:bank_select(chan, bank)
   fluid.fluid_synth_bank_select(self.synth, chan, bank)
end

function Synth_mt:sfont_select(chan, sfont_id)
   fluid.fluid_synth_sfont_select(self.synth, chan, sfont_id)
end

function Synth_mt:program_select(chan, sfont_id, bank_num, preset_num)
   fluid.fluid_synth_program_select(self.synth, chan, sfont_id, bank_num, preset_num)
end

function Synth_mt:get_channel_info(chan)
   local info = ffi.new("fluid_synth_channel_info_t")
   util.check_ok("fluid_synth_get_channel_info", fluid.FLUID_OK, fluid.fluid_synth_get_channel_info(self.synth, chan, info))
   return {
      assigned = info.assigned == 1,
      sfont_id = info.sfont_id,
      bank = info.bank,
      program = info.program,
      name = ffi.string(info.name),
   }
end

function Synth_mt:program_reset()
   fluid.fluid_synth_program_reset(self.synth)
end

function Synth_mt:system_reset()
   fluid.fluid_synth_system_reset(self.synth)
end

function Synth_mt:all_notes_off(chan)
   fluid.fluid_synth_all_notes_off(self.synth, chan)
end

function Synth_mt:all_sounds_off(chan)
   fluid.fluid_synth_all_sounds_off(self.synth, chan)
end

function Synth_mt:set_channel_type(chan, type)
   fluid.fluid_synth_set_channel_type(self.synth, chan, type)
end

function Synth_mt:sfload(filename, reset_presets)
   local id = fluid.fluid_synth_sfload(self.synth, filename, reset_presets)
   if id == fluid.FLUID_FAILED then
      ef("fluid_synth_sfload() failed: %s", self:error())
   end
   return id
end

function Synth_mt:set_sample_rate(sample_rate)
   fluid.fluid_synth_set_sample_rate(self.synth, sample_rate)
end

function Synth_mt:set_gain(gain)
   fluid.fluid_synth_set_gain(self.synth, gain)
end

function Synth_mt:get_gain()
   return fluid.fluid_synth_get_gain(self.synth)
end

function Synth_mt:set_polyphony(polyphony)
   fluid.fluid_synth_set_polyphony(self.synth, polyphony)
end

function Synth_mt:get_polyphony()
   return fluid.fluid_synth_get_polyphony(self.synth)
end

function Synth_mt:get_active_voice_count()
   return fluid.fluid_synth_get_active_voice_count(self.synth)
end

function Synth_mt:get_internal_bufsize()
   return fluid.fluid_synth_get_internal_bufsize(self.synth)
end

function Synth_mt:get_cpu_load()
   return fluid.fluid_synth_get_cpu_load(self.synth)
end

function Synth_mt:error()
   return ffi.string(fluid.fluid_synth_error(self.synth))
end

function Synth_mt:delete()
   if self.synth ~= nil then
      fluid.delete_fluid_synth(self.synth)
      self.synth = nil
   end
end

Synth_mt.__index = Synth_mt
Synth_mt.__gc = Synth_mt.delete
local Synth = ffi.metatype("struct zz_fluidsynth_synth", Synth_mt)

function M.Synth(settings)
   local synth = fluid.new_fluid_synth(settings.settings)
   return Synth(synth)
end

function M.AudioSource(synth)
   local source = audio.Source("struct zz_fluidsynth_audio_source",
                            ffi.C.zz_fluidsynth_audio_callback,
                            synth.synth)
   return {
      source = source, -- prevent GC
      src = source.src,
   }
end

return M
