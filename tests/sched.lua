local sched = require('sched')
local time = require('time')
local sys = require('sys')
local signal = require('signal')
local assert = require('assert')
local sf = string.format

-- "stress-test" scheduler creation and release

for i=1,10 do
   sched(function() sched.yield() end)
   sched()
end

-- coroutines

local coll = {}

local function make_co(value, steps, inc)
   return function()
      while steps > 0 do
         table.insert(coll, value)
         value = value + inc
         steps = steps - 1
         sched.yield()
      end
   end
end

sched(make_co(1,10,1))
sched(make_co(2,6,2))
sched(make_co(3,7,3))
sched()

local expected = { 
   1,  2,  3,
   2,  4,  6,
   3,  6,  9,
   4,  8, 12,
   5, 10, 15,
   6, 12, 18,
   7,     21,
   8,
   9,
   10,
}

assert(#expected == #coll)
for i=1,#expected do
   assert(coll[i] == expected[i])
end

-- sched(fn, data):
-- wrap fn into a new thread, schedule it for later execution
-- pass data as a single arg when the thread is first resumed

local output = nil

sched(function(x) output = x end, 42)
sched()
assert(output == 42)

-- sched.on(evtype, callback):
-- invoke callback(evdata) when an `evtype' event arrives

local counter = 0
sched.on('my-signal-forever',
         function(inc)
            counter = counter + inc
         end)

-- sched.emit(evtype, evdata):
-- post a new event to the event queue
--
-- any threads waiting for this evtype will wake up
sched(function()
         sched.emit('my-signal-forever', 42.5)
         sched.yield() -- give a chance to the signal handler
         -- event callbacks registered with sched.on() keep on waiting
         -- (no matter how many times the callback has been invoked)
         sched.emit('my-signal-forever', 10)
         sched.yield() -- give another chance to the signal handler
      end)
sched()
assert.equals(counter, 42.5+10)

-- if you want to stop listening, return sched.OFF from the callback
local counter = 0
sched.on('my-signal-once',
         function(inc)
            counter = counter + inc
            return sched.OFF
         end)
sched(function()
         sched.emit('my-signal-once', 5)
         sched.yield()
         sched.emit('my-signal-once', 7)
         sched.yield()
      end)
sched()
assert.equals(counter, 5)

-- a 'quit' event terminates the event loop

local counter = 0
sched(function()
         while true do
            sched.yield()
            counter = counter + 1
            if counter == 10 then
               sched.quit()
            end
         end
      end)
sched()
assert.equals(counter, 10)

-- sched.wait(evtype):
-- go to sleep, wake up when an event of type `evtype' arrives
-- the event's data is returned by the sched.wait() call

local output = nil
sched(function()
         local wake_up_data = sched.wait('wake-up')
         assert(type(wake_up_data)=="table")
         assert(wake_up_data.value == 43)
         output = wake_up_data.value
      end)
-- we emit after the previous thread had executed sched.wait()
-- otherwise sched() would exit immediately
sched(function()
         sched.emit('wake-up', { value = 43 })
      end)
sched()
assert(output == 43, sf("output=%s", output))

-- sched.wait() also accepts a positive number (a timestamp)
-- in that case, the thread will be resumed at the specified time
local wait_amount = 0.1 -- seconds
local now = time.time()
local time_after_wait = nil
sched(function()
         sched.wait(time.time() + wait_amount)
         -- we could also use sched.sleep():
         -- sched.sleep(x) = sched.wait(time.time()+x)
         time_after_wait = time.time()
      end)
sched()
assert.type(time_after_wait, 'number')
local elapsed = time_after_wait-now
local diff = math.abs(wait_amount - elapsed) -- error
-- we expect millisecond precision
assert(diff < 1e-3, "diff > 1e-3: "..tostring(diff))

-- a thread sleeping in sched.wait() keeps the event loop alive
local pid = sys.fork()
if pid == 0 then
   sched(function()
            sched.wait('quit')
         end)
   sched()
   sys.exit()
else
   time.sleep(0.1)
   -- subprocess still exists after 100 ms
   assert(signal.kill(pid, 0)==0)
   -- let's send it a SIGTERM (which will cause a sched.quit())
   signal.kill(pid, signal.SIGTERM)
   -- wait for it
   assert(sys.waitpid(pid)==pid)
   -- now it should not exist any more
   assert.equals(signal.kill(pid, 0), -1, "result of signal.kill(pid,0) after child got SIGTERM")
end

-- callbacks registered with sched.on() do not keep the event loop alive
local output = {}
sched.on('my-signal',
         function()
            table.insert(output, "signal-handler-1")
         end)
sched(function()
         table.insert(output, "signal-sent")
         sched.emit('my-signal', 0)
         -- this thread will now exit, so the number of running or
         -- waiting threads goes down to zero. as a result, neither of
         -- the registered my-signal handlers will be called.
      end)
sched.on('my-signal',
         function()
            table.insert(output, "signal-handler-2")
         end)
sched()
assert.equals(output, {"signal-sent"})

-- one way to ensure that no signal gets lost is to call sched.yield()
-- as the last statement of the thread which emits the signal which
-- should be handled. this ensures a last tick of the event loop, in
-- which all pending callbacks will be scheduled for execution.
local output = {}
sched.on('my-signal',
         function()
            table.insert(output, "signal-handler-1")
         end)
sched(function()
         table.insert(output, "signal-sent")
         sched.emit('my-signal', 0)
         sched.yield()
      end)
sched.on('my-signal',
         function()
            table.insert(output, "signal-handler-2")
         end)
sched()
assert.equals(output, {"signal-sent", "signal-handler-1", "signal-handler-2"})

-- note that the above behaviour does not apply to the 'quit' signal:
-- callbacks for 'quit' are always called at the end and then removed

local output = {}
sched.on('quit',
         function()
            table.insert(output, "quit-handler-1")
         end)
sched(function()
         table.insert(output, "sched.quit")
         sched.quit()
      end)
sched.on('quit',
         function()
            table.insert(output, "quit-handler-2")
         end)
sched()
assert.equals(output, {"sched.quit", "quit-handler-1", "quit-handler-2"})

-- quit callbacks are called even if the code doesn't invoke
-- sched.quit() explicitly. in that case, the scheduler makes an
-- implicit call when all threads exit.

local output = {}
sched.on('quit',
         function()
            table.insert(output, "quit-handler-1")
         end)
sched(function()
         -- main thread
         table.insert(output, "sched.quit")
      end)
sched.on('quit',
         function()
            table.insert(output, "quit-handler-2")
         end)
sched()
assert.equals(output, {"sched.quit", "quit-handler-1", "quit-handler-2"})