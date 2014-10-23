local ffi = require('ffi')
local msgpack = require('msgpack')
local nn = require('nanomsg')
local sched = require('sched')
local inspect = require('inspect')
local sf = string.format

ffi.cdef [[

typedef void (*zz_async_worker)(cmp_ctx_t *request,
                                cmp_ctx_t *reply,
                                int nargs);

int   zz_register_worker(zz_async_worker worker);
void *zz_async_worker_thread(void *arg);

void  zz_async_echo_worker(cmp_ctx_t *request,
                           cmp_ctx_t *reply,
                           int nargs);

]]

local M = {}

local MAX_THREADS = 16

local reservable_threads = {}
local active_threads = 0

local worker_thread_count = 0

local function create_worker_thread()
   worker_thread_count = worker_thread_count + 1
   local thread_id = ffi.new("pthread_t[1]")
   local rv = ffi.C.pthread_create(thread_id,
                                   nil,
                                   ffi.C.zz_async_worker_thread,
                                   ffi.cast("void*", worker_thread_count))
   if rv ~= 0 then
      error("cannot create async worker thread: pthread_create() failed")
   end
   local self = {
      thread_id = thread_id,
      thread_no = worker_thread_count,
      socket = nn.socket(nn.AF_SP, nn.PAIR),
   }
   local sockaddr = sf("inproc://async_%04x", self.thread_no)
   nn.connect(self.socket, sockaddr)
   function self:send(msg)
      nn.send(self.socket, msg)
   end
   return self
end

local function reserve_thread()
   local t
   if #reservable_threads == 0 then
      if active_threads == MAX_THREADS then
         error(sf("exceeded max number of threads (%d), cannot reserve more", MAX_THREADS))
      else
         t = create_worker_thread()
      end
   else
      t = table.remove(reservable_threads)
   end
   active_threads = active_threads + 1
   return t
end

local function release_thread(t)
   table.insert(reservable_threads, t)
   active_threads = active_threads - 1
end

local msg_id = 0
local function next_msg_id()
   msg_id = msg_id - 1
   -- naive attempt to handle wraparound
   if msg_id > 0 then
      msg_id = -1
   end
   return msg_id
end

function M.register_worker(worker)
   return ffi.C.zz_register_worker(worker)
end

function M.request(worker_id, ...)
   local msg_id = next_msg_id()
   local msg = msgpack.pack_array({worker_id, msg_id, ...})
   local t = reserve_thread()
   t:send(msg)
   local rv = sched.yield(msg_id)
   release_thread(t)
   return rv
end

return M
