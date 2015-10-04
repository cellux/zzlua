local util = require('util')
local assert = require('assert')

-- accumulator

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

-- classes

-- a class without a `create' method creates empty tables as instances
local A = util.Class()
local a = A()
assert.equals(a, {})

-- if we pass a single table to the constructor, it will be the instance
local a = A { x=5, y=8 }
assert.equals(a, { x=5, y=8 })

-- if we define a `create' method, it will be used to create instances
local A = util.Class()
function A:create(opts)
   return opts or {"undefined"}
end
function A:f()
   return 5
end
function A:g()
   return "hello"
end
local a = A { x=1, y=2 }
assert.equals(a, { x=1, y=2 })
assert.equals(a:f(), 5)

-- inheritance

local B = util.Class(A) -- specify the parent as a single argument
local b = B()
assert.equals(b, {"undefined"}) -- create method inherited from A
assert.equals(b:g(), "hello")

local C = util.Class(B)
local c = C()
assert.equals(c:f(), 5)

function B:f()
   return 10
end

assert.equals(c:f(), 10)

local c = C { a=1, b=3, c=8 }
assert.equals(c, { a=1, b=3, c=8 })
assert.equals(c:f(), 10)
assert.equals(c:g(), "hello")

-- EventEmitter

local obj = util.EventEmitter {
   x = 5,
   s = "abc",
   f = 1.5,
}

function obj:change_something()
   self.x = 10
   self:emit('something-changed', 1, 2, 3)
end

obj:on('something-changed', function(...)
   assert.equals({...}, {1,2,3})
   obj.s = "hulaboy"
end)

obj:on('something-changed', function(...)
   assert.equals({...}, {1,2,3})
   obj.f = -12.5
end)

assert.equals(obj.x, 5)
assert.equals(obj.s, "abc")
assert.equals(obj.f, 1.5)

obj:change_something()

assert.equals(obj.x, 10)
assert.equals(obj.s, "hulaboy")
assert.equals(obj.f, -12.5)
