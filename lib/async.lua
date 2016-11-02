local ffi = require('ffi')
local msgpack = require('msgpack')
local nn = require('nanomsg')
local sched = require('sched')
local pthread = require('pthread')
local inspect = require('inspect')
local adt = require('adt')

ffi.cdef [[

typedef void (*zz_async_handler)(cmp_ctx_t *request,
                                 cmp_ctx_t *reply,
                                 int nargs);

int zz_async_register_worker(void *handlers[]);

void *zz_async_worker_thread(void *arg);

enum {
  ZZ_ASYNC_ECHO
};

void *zz_async_echo_handlers[];

]]

local M = {}

local MAX_ACTIVE_THREADS = 16

local thread_pool        = {} -- a list of reservable threads
local active_threads     = {} -- event_id -> thread

local n_active_threads   = 0
local n_worker_threads   = 0

local request_queue = adt.List()

local function create_worker_thread()
   n_worker_threads = n_worker_threads + 1
   local thread_id = ffi.new("pthread_t[1]")
   local rv = ffi.C.pthread_create(thread_id,
                                   nil,
                                   ffi.C.zz_async_worker_thread,
                                   ffi.cast("void*", n_worker_threads))
   if rv ~= 0 then
      error("cannot create async worker thread: pthread_create() failed")
   end
   local self = {
      thread_id = thread_id,
      thread_no = n_worker_threads,
      socket = nn.socket(nn.AF_SP, nn.PAIR)
   }
   local sockaddr = sf("inproc://async_%04x", self.thread_no)
   nn.connect(self.socket, sockaddr)
   function self:send(msg)
      nn.send(self.socket, msg)
   end
   function self:stop()
      local exit_msg = msgpack.pack_array({})
      nn.send(self.socket, exit_msg)
      local retval = ffi.new("void*[1]")
      local rv = ffi.C.pthread_join(self.thread_id[0], retval)
      if rv ~=0 then
         error("cannot join async worker thread: pthread_join() failed")
      end
      nn.close(self.socket)
      n_worker_threads = n_worker_threads - 1
   end
   return self
end

local function can_reserve_thread()
   return #thread_pool > 0 or n_active_threads < MAX_ACTIVE_THREADS
end

local function reserve_thread(event_id)
   local t
   if #thread_pool == 0 then
      if n_active_threads == MAX_ACTIVE_THREADS then
         ef("exceeded max number of threads (%d), cannot reserve more",
            MAX_ACTIVE_THREADS)
      else
         t = create_worker_thread()
      end
   else
      t = table.remove(thread_pool)
   end
   assert(active_threads[event_id] == nil)
   active_threads[event_id] = t
   n_active_threads = n_active_threads + 1
   return t
end

local function release_thread(event_id)
   local t = active_threads[event_id]
   assert(t)
   table.insert(thread_pool, t)
   n_active_threads = n_active_threads - 1
   active_threads[event_id] = nil
end

local function stop_all_threads()
   assert(n_active_threads == 0)
   for _,t in ipairs(thread_pool) do
      t:stop()
   end
   assert(n_worker_threads == 0)
   thread_pool = {}
end

function M.register_worker(handlers)
   return ffi.C.zz_async_register_worker(handlers)
end

function M.request(worker_id, handler_id, ...)
   local event_id = sched.make_event_id()
   local msg = msgpack.pack_array({worker_id, handler_id, event_id, ...})
   request_queue:push({msg, event_id})
   -- will be serviced as soon as a thread becomes available
   local rv = sched.wait(event_id)
   release_thread(event_id)
   return rv
end

local function AsyncModule(sched)
   local self = {}
   function self.init()
      thread_pool = {}
      active_threads = {}
      n_active_threads = 0
      n_worker_threads = 0
      request_queue = adt.List()
   end
   function self.tick()
      while not request_queue:empty() and can_reserve_thread() do
         local msg, event_id = unpack(request_queue:shift())
         local t = reserve_thread(event_id)
         t:send(msg)
      end
   end
   function self.done()
      stop_all_threads()
   end
   return self
end

sched.register_module(AsyncModule)

return M
