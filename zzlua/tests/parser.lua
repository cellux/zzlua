local re = require('re')
local parser = require('parser')
local sf = string.format

local p = parser.Parser("hello, world!\n")
assert(p)
assert(p.source == "hello, world!\n")
assert(p.len == 14)
assert(p.pos == 0)
assert(not p:eof())
local ok, msg = pcall(p.eat, p, "ello")
assert(not ok)
assert(re.match("expected a match for ello at position", msg))
local hello = p:eat("h.l*o")
assert(hello=="hello", sf("hello=%s", hello))
local world = p:eat("\\W+\\w+")
assert(world==", world", sf("world=%s", world))
assert(p:eat("[!\n]{2}")=="!\n")
assert(p:eof())
