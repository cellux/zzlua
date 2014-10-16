local ffi = require('ffi')

-- use size_t instead of long int because it has the right size on
-- both 32 and 64 bit architectures

ffi.cdef [[
typedef size_t __time_t;
typedef size_t __suseconds_t;

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

typedef size_t __syscall_slong_t;

struct timespec {
  __time_t tv_sec;
  __syscall_slong_t tv_nsec;
};

int nanosleep (const struct timespec *requested_time,
               struct timespec *remaining);

]]

local M = {}

function M.time()
   -- return number of seconds elapsed since epoch
   local TP = ffi.new("struct timeval")
   if ffi.C.gettimeofday(TP, nil) ~= 0 then
      error("gettimeofday() failed")
   end
   -- on 64-bit architectures TP.tv_sec and TP.tv_usec are boxed
   return tonumber(TP.tv_sec) + tonumber(TP.tv_usec) / 1e6
end

function M.sleep(seconds)
   -- sleep for the given number of seconds
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

function M.async_sleep(seconds)
   -- required here to avoid circular dependency
   -- between sched and time
   local sched = require('sched')
   sched.yield(M.time()+seconds)
end

return M
