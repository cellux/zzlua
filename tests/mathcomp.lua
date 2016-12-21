local ffi = require('ffi')
local mathcomp = require('mathcomp')
local assert = require('assert')

-- arrays within structs

ffi.cdef [[
struct zz_test_mathcomp_1 {
  float output1[3];
};
]]

local s = ffi.new("struct zz_test_mathcomp_1")
s.output1[0] = 1
s.output1[1] = -2.5
s.output1[2] = 3.75
assert.equals(s.output1[0], 1)
assert.equals(s.output1[1], -2.5)
assert.equals(s.output1[2], 3.75)

-- proof that fields within inner structs can be aliased, read and
-- written to

ffi.cdef [[
struct zz_test_mathcomp_2 {
  int x;
  struct {
    int x;
  } inner;
};
]]

local s = ffi.new("struct zz_test_mathcomp_2")
s.x = 5
s.inner.x = 8;
local inner = s.inner
assert.equals(inner.x, 8)
inner.x = 10
assert.equals(s.inner.x, 10)

-- CompilerContext

local cc = mathcomp.CompilerContext {
   -- use double as the numeric type of input/ouput parameters
   --
   -- the default is float - this would cause the comparison of test
   -- results to fail as Lua calculates with doubles
   numtype = 'double'
}

local v1 = cc:vec(3, {1, 2, 3})
local v2 = cc:vec(3, {4, 5, 6})

-- create compilation unit with two output parameters (targets)
local unit = cc:compile(v1, v2)

-- call unit to calculate output(s)
unit:calculate()

-- retrieve output(s)
local v1_value, v2_value = unit:outputs()
assert.equals(v1_value[0], 1)
assert.equals(v1_value[1], 2)
assert.equals(v1_value[2], 3)
assert.equals(v2_value[0], 4)
assert.equals(v2_value[1], 5)
assert.equals(v2_value[2], 6)

-- vectors

-- passing a number in the second arg of vec() causes all elements to
-- be initialized with that number

local v_zero = cc:vec(3, 0) -- additive identity
local value = cc:compile(v_zero):calculate():outputs()
assert.equals(value[0], 0)
assert.equals(value[1], 0)
assert.equals(value[2], 0)

local v_one = cc:vec(3, 1) -- multiplicative identity
local value = cc:compile(v_one):calculate():outputs()
assert.equals(value[0], 1)
assert.equals(value[1], 1)
assert.equals(value[2], 1)

local v1_neg = -v1 -- additive inverse of v1={1,2,3}
local value = cc:compile(v1_neg):calculate():outputs()
assert.equals(value[0], -1)
assert.equals(value[1], -2)
assert.equals(value[2], -3)

local value = cc:compile(v1+v1_neg):calculate():outputs()
assert.equals(value[0], 0)
assert.equals(value[1], 0)
assert.equals(value[2], 0)

-- magnitude (length)
local value = cc:compile(v2:mag()):calculate():outputs()
assert.equals(value, math.sqrt(4*4+5*5+6*6))

-- the length of a vector is its magnitude
local value = cc:compile(#v2):calculate():outputs()
assert.equals(value, math.sqrt(4*4+5*5+6*6))

-- dot product
local value = cc:compile(cc:dot(v1,v2)):calculate():outputs()
assert.equals(value, 1*4 + 2*5 + 3*6)

local unit = cc:compile(cc:dot(cc:vec(2,{4,6}), cc:vec(2,{-3,7})))
local value = unit:calculate():outputs()
assert.equals(value, 30)

local unit = cc:compile(cc:dot(cc:vec(3,{3,-2,7}), cc:vec(3,{0,4,-1})))
local value = unit:calculate():outputs()
assert.equals(value, -15)

-- cross product
local unit = cc:compile(cc:cross(cc:vec(3,{1,3,-4}), cc:vec(3,{2,-5,8})))
local value = unit:calculate():outputs()
assert.equals(value[0], 4)
assert.equals(value[1], -16)
assert.equals(value[2], -11)

-- 0 <= angle < 90 => dot product is positive
local unit = cc:compile(cc:dot(cc:vec(2, {0,10}), cc:vec(2, {10,1})))
local value = unit:calculate():outputs()
assert(value > 0)

-- angle == 90 => dot product is zero
local unit = cc:compile(cc:dot(cc:vec(2, {0,10}), cc:vec(2, {10,0})))
local value = unit:calculate():outputs()
assert(value == 0)

-- 90 < angle <= 180 => dot product is negative
local unit = cc:compile(cc:dot(cc:vec(2, {0,10}), cc:vec(2, {10,-1})))
local value = unit:calculate():outputs()
assert(value < 0)

-- vector * scalar
local value = cc:compile(v1*2.5):calculate():outputs()
assert.equals(value[0], 2.5)
assert.equals(value[1], 5.0)
assert.equals(value[2], 7.5)

-- scalar * vector
local value = cc:compile(1.5*v2):calculate():outputs()
assert.equals(value[0], 6)
assert.equals(value[1], 7.5)
assert.equals(value[2], 9)

-- vector / scalar
local value = cc:compile(v2/4):calculate():outputs()
assert.equals(value[0], 4/4)
assert.equals(value[1], 5/4)
assert.equals(value[2], 6/4)

-- normalize
local value = cc:compile(v2:normalize()):calculate():outputs()
local scale = 1 / math.sqrt(4*4 + 5*5 + 6*6)
assert.equals(value[0], 4*scale)
assert.equals(value[1], 5*scale)
assert.equals(value[2], 6*scale)

-- vector + vector
local value = cc:compile(v1+v2):calculate():outputs()
assert.equals(value[0], 5)
assert.equals(value[1], 7)
assert.equals(value[2], 9)

-- vector - vector
local value = cc:compile(v1-v2):calculate():outputs()
assert.equals(value[0], 1-4)
assert.equals(value[1], 2-5)
assert.equals(value[2], 3-6)

-- distance
local value = cc:compile(cc:distance(v1,v2)):calculate():outputs()
assert.equals(value, math.sqrt(27))

-- angle
local unit = cc:compile(cc:angle(cc:vec(2,{0,10}), cc:vec(2,{7,0})))
local value = unit:calculate():outputs()
assert.equals(value, math.pi/2)

-- angle is always positive
local unit = cc:compile(cc:angle(cc:vec(2,{0,10}), cc:vec(2,{-7,0})))
local value = unit:calculate():outputs()
assert.equals(value, math.pi/2)

-- projection of one vector onto another
local unit = cc:compile(cc:vec(2,{3,7}):project(cc:vec(2,{6,0})))
local value = unit:calculate():outputs()
assert.equals(value[0], 3)
assert.equals(value[1], 0)

local unit = cc:compile(cc:vec(2,{3,7}):project(cc:vec(2,{0,-6})))
local value = unit:calculate():outputs()
assert.equals(value[0], 0)
assert.equals(value[1], 7)

-- matrix * matrix (2x2)
local m1 = cc:mat(2,2,{-3,5,0,1/2})
local m2 = cc:mat(2,2,{-7,4,2,6})
local value = cc:compile(m1*m2):calculate():outputs()
assert.equals(value[0], 21)
assert.equals(value[1], -33)
assert.equals(value[2], -6)
assert.equals(value[3], 13)

-- matrix * matrix (3x3)
local m1 = cc:mat(3,3,{1,0,7,-5,-2,2,3,6,-4})
local m2 = cc:mat(3,3,{-8,7,2,6,0,4,1,-3,5})
local value = cc:compile(m1*m2):calculate():outputs()
assert.equals(value[0], -37)
assert.equals(value[1], -2)
assert.equals(value[2], -50)
assert.equals(value[3], 18)
assert.equals(value[4], 24)
assert.equals(value[5], 26)
assert.equals(value[6], 31)
assert.equals(value[7], 36)
assert.equals(value[8], -19)

-- matrix * vector
local m1 = cc:mat(2,2,{-3,5,0,1/2})
local v2 = cc:vec(2,{-7,4})
local value = cc:compile(m1*v2):calculate():outputs()
assert.equals(value[0], 21)
assert.equals(value[1], -33)

-- vector * matrix
local v1 = cc:vec(3,{1,-5,3})
local m2 = cc:mat(3,3,{-8,7,2,6,0,4,1,-3,5})
local value = cc:compile(v1*m2):calculate():outputs()
assert.equals(value[0], -37)
assert.equals(value[1], 18)
assert.equals(value[2], 31)

-- transpose
local m1 = cc:mat(3,3,{1,0,7,-5,-2,2,3,6,-4})
local value = cc:compile(m1:transpose()):calculate():outputs()
assert.equals(value[0], 1)
assert.equals(value[1], -5)
assert.equals(value[2], 3)
assert.equals(value[3], 0)
assert.equals(value[4], -2)
assert.equals(value[5], 6)
assert.equals(value[6], 7)
assert.equals(value[7], 2)
assert.equals(value[8], -4)

local m2 = cc:mat(3,3,{-8,7,2,6,0,4,1,-3,5})
local value1,value2 = cc:compile((m1*m2):transpose(), m2:transpose()*m1:transpose()):calculate():outputs()
for i=0,8 do
   assert.equals(value1[i], value2[i])
end
