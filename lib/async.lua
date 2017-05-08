local ffi = require('ffi')
local util = require('util')
local sched = require('sched')
local pthread = require('pthread')
local inspect = require('inspect')
local adt = require('adt')
local errno = require('errno')

ffi.cdef [[

enum {
  EFD_SEMAPHORE = 00000001,
  EFD_CLOEXEC   = 02000000,
  EFD_NONBLOCK  = 00004000
};

int eventfd(unsigned int initval, int flags);

ssize_t read (int FILEDES, void *BUFFER, size_t SIZE);
ssize_t write (int FILEDES, const void *BUFFER, size_t SIZE);
int close (int FILEDES);

typedef void (*zz_async_handler)(void *request_data);

int zz_async_register_worker(void *handlers[]);

struct zz_async_worker_info {
  int request_fd;
  int worker_id;
  int handler_id;
  void *request_data;
  int response_fd;
};

void *zz_async_worker_thread(void *arg);

enum {
  ZZ_ASYNC_ECHO
};

struct zz_async_echo_request {
  double delay;
  double payload;
  double response;
};

void *zz_async_handlers[];

]]

local M = {}

local MAX_ACTIVE_THREADS = 16

local thread_pool   = {} -- a list of reservable threads

local reserve_queue = adt.List() -- event ids of coroutines waiting
                                 -- for a reservable thread

local n_active_threads   = 0
local n_worker_threads   = 0

local function create_worker_thread()
   n_worker_threads = n_worker_threads + 1
   local worker_info = ffi.new("struct zz_async_worker_info")
   local request_fd = util.check_errno("eventfd", ffi.C.eventfd(0, ffi.C.EFD_NONBLOCK))
   worker_info.request_fd = request_fd
   local response_fd = util.check_errno("eventfd", ffi.C.eventfd(0, ffi.C.EFD_NONBLOCK))
   sched.poll_add(response_fd, "r")
   worker_info.response_fd = response_fd
   local thread_id = ffi.new("pthread_t[1]")
   local rv = ffi.C.pthread_create(thread_id,
                                   nil,
                                   ffi.C.zz_async_worker_thread,
                                   ffi.cast("void*", worker_info))
   if rv ~= 0 then
      error("cannot create async worker thread: pthread_create() failed")
   end
   local self = {}
   local trigger = ffi.new("uint64_t[1]")
   function self:send_request(worker_id, handler_id, request_data, sync)
      worker_info.worker_id = worker_id
      worker_info.handler_id = handler_id
      worker_info.request_data = request_data
      trigger[0] = 1
      local nbytes = ffi.C.write(request_fd, trigger, 8)
      assert(nbytes==8)
      while true do
         if not sync then
            sched.poll(response_fd, "r")
         end
         trigger[0] = 0
         local nbytes = ffi.C.read(response_fd, trigger, 8)
         if nbytes == -1 then
            local errnum = errno.errno()
            if errnum ~= ffi.C.EAGAIN then
               ef("poll(response_fd) failed: %s", errno.strerror(errnum))
            end
         elseif nbytes ~= 8 then
            ef("poll(response_fd) failed: read %d bytes, expected 8", nbytes)
         elseif tonumber(trigger[0]) ~= 1 then
            ef("poll(response_fd) failed: trigger[0] ~= 1")
         else
            -- we got the trigger
            break
         end
      end
   end
   function self:stop()
      self:send_request(-1, 0, nil, true)
      local retval = ffi.new("void*[1]")
      local rv = ffi.C.pthread_join(thread_id[0], retval)
      if rv ~=0 then
         error("cannot join async worker thread: pthread_join() failed")
      end
      sched.poll_del(response_fd)
      util.check_errno("close", ffi.C.close(response_fd))
      util.check_errno("close", ffi.C.close(request_fd))
      n_worker_threads = n_worker_threads - 1
   end
   return self
end

local function reserve_thread()
   local t
   if #thread_pool == 0 then
      if n_active_threads == MAX_ACTIVE_THREADS then
         local reservation_id = sched.make_event_id()
         reserve_queue:push(reservation_id)
         -- block until we get a free thread
         t = sched.wait(reservation_id)
      else
         t = create_worker_thread()
      end
   else
      t = table.remove(thread_pool)
   end
   n_active_threads = n_active_threads + 1
   return t
end

local function release_thread(t)
   n_active_threads = n_active_threads - 1
   if reserve_queue:empty() then
      -- nobody is waiting for a thread, put it back to the pool
      table.insert(thread_pool, t)
   else
      local reservation_id = reserve_queue:shift()
      sched.emit(reservation_id, t)
   end
end

function M.register_worker(handlers)
   return ffi.C.zz_async_register_worker(handlers)
end

function M.request(worker_id, handler_id, request_data)
   -- reserve_thread() blocks if needed
   -- until a thread becomes available
   local t = reserve_thread()
   t:send_request(worker_id, handler_id, request_data)
   release_thread(t)
end

local function AsyncModule(sched)
   local self = {}
   function self.init()
      thread_pool = {}
      reserve_queue = adt.List()
      n_active_threads = 0
      n_worker_threads = 0
   end
   function self.done()
      assert(n_active_threads == 0)
      assert(reserve_queue:empty())
      for _,t in ipairs(thread_pool) do
         t:stop()
      end
      assert(n_worker_threads == 0)
      thread_pool = {}
   end
   return self
end

sched.register_module(AsyncModule)

return M
