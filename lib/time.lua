local ffi = require('ffi')

ffi.cdef [[

typedef long int __time_t;
typedef long int __syscall_slong_t;

struct timespec {
  __time_t tv_sec;
  __syscall_slong_t tv_nsec;
};

typedef long int __suseconds_t;

struct timeval {
  __time_t tv_sec;            /* Seconds.  */
  __suseconds_t tv_usec;      /* Microseconds.  */
};

struct timezone {
  int tz_minuteswest;
  int tz_dsttime;
};

int gettimeofday (struct timeval *TP,
                  struct timezone *TZP);

/* struct timespec is predefined for us by zzlua */
int nanosleep (const struct timespec *requested_time,
               struct timespec *remaining);

typedef int32_t clockid_t;

int clock_gettime(clockid_t clk_id, struct timespec *tp);

]]

local M = {}

function M.time()
   -- return number of seconds elapsed since epoch
   local tp = ffi.new("struct timespec")
   if ffi.C.clock_gettime(0, tp) ~= 0 then
      error("clock_gettime() failed")
   end
   -- on 64-bit architectures tp.tv_sec and tp.tv_nsec are boxed
   return tonumber(tp.tv_sec) + tonumber(tp.tv_nsec) / 1e9
end

function M.nanosleep(seconds)
   local requested_time = ffi.new("struct timespec")
   local integer_part = math.floor(seconds)
   requested_time.tv_sec = integer_part
   local float_part = seconds - integer_part
   local ns = float_part * 1e9
   requested_time.tv_nsec = ns
   local remaining = ffi.new("struct timespec")
   if ffi.C.nanosleep(requested_time, remaining) ~= 0 then
      error("nanosleep() failed")
   end
end

function M.sleep(seconds)
   -- sleep for the given number of seconds
   if coroutine.running() then
      -- required here to avoid circular dependency
      -- between sched and time
      local sched = require('sched')
      sched.sleep(seconds)
   else
      M.nanosleep(seconds)
   end
end

return M
