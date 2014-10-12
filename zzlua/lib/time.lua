local ffi = require('ffi')

ffi.cdef [[
typedef long int __time_t;
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

typedef long int __syscall_slong_t;

struct timespec {
  __time_t tv_sec;
  __syscall_slong_t tv_nsec;
};

int nanosleep (const struct timespec *REQUESTED_TIME,
               struct timespec *REMAINING);

]]

local M = {}

function M.time()
   -- return number of seconds elapsed since epoch
   local TP = ffi.new("struct timeval")
   if ffi.C.gettimeofday(TP, nil) ~= 0 then
      error("gettimeofday() failed")
   end
   return TP.tv_sec + TP.tv_usec / 1e6
end

function M.sleep(seconds)
   -- sleep for the given number of seconds
   local REQUESTED_TIME = ffi.new("struct timespec")
   REQUESTED_TIME.tv_sec = math.floor(seconds)
   local float_part = seconds - REQUESTED_TIME.tv_sec
   local ns = float_part * 1e9
   REQUESTED_TIME.tv_nsec = ns
   local REMAINING = ffi.new("struct timespec")
   if ffi.C.nanosleep(REQUESTED_TIME, REMAINING) ~= 0 then
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
