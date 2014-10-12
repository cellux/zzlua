local time = require('time')

local t1 = time.time()
local sleep_time = 0.1
time.sleep(sleep_time)
local t2 = time.time()
local elapsed = t2 - t1
local diff = math.abs(elapsed - sleep_time)
local max_diff = 1e-3 -- we expect millisecond precision
assert(diff < max_diff, string.format("there are problems with timer precision: diff (%f) >= max allowed diff (%f)", diff, max_diff))
