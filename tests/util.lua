local util = require('util')
local assert = require('assert')

local accum = util.Accumulator()
accum:feed(5)
accum(8)
accum(-3)
assert.equals(accum.n, 3)
assert.equals(accum.sum, 5+8-3)
assert.equals(accum.avg, (5+8-3)/3)
assert.equals(accum.min, -3)
assert.equals(accum.max, 8)
assert.equals(accum.last, -3)