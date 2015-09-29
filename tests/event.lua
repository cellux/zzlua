local event = require('event')
local assert = require('assert')

local obj = event.Emitter {
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
