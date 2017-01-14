local ffi = require('ffi')
local mathx = require('mathx')
local assert = require('assert')

-- Thanks to Fletcher Dunn and Ian Parberry - authors of "3D Math
-- Primer for Graphics and Game Development" - for writing such a fine
-- book on this subject. The descriptions in that book proved
-- invaluable when I was writing the code of this module.

-- Compiler

local cc = mathx.Compiler { -- cc stands for compiler context
   -- use double as the numeric type of input/ouput parameters
   --
   -- the default is float - with that setting the checking of test
   -- results would fail due to floating point inaccuracies (Lua
   -- calculates with doubles)
   numtype = 'double'
}

local v1 = cc:vec(3, {1, 2, 3})
local v2 = cc:vec(3, {4, 5, 6})

-- compile function with two output parameters
local f = cc:compile(v1, v2)

-- run the generated code, retrieve output(s)
local v1_value, v2_value = f()
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
local value = cc:compile(v_zero)()
assert.equals(value[0], 0)
assert.equals(value[1], 0)
assert.equals(value[2], 0)

local v_one = cc:vec(3, 1) -- multiplicative identity
local value = cc:compile(v_one)()
assert.equals(value[0], 1)
assert.equals(value[1], 1)
assert.equals(value[2], 1)

local v1_neg = -v1 -- additive inverse of v1={1,2,3}
local value = cc:compile(v1_neg)()
assert.equals(value[0], -1)
assert.equals(value[1], -2)
assert.equals(value[2], -3)

local value = cc:compile(v1+v1_neg)()
assert.equals(value[0], 0)
assert.equals(value[1], 0)
assert.equals(value[2], 0)

-- magnitude (length)
local value = cc:compile(v2:mag())()
assert.equals(value, math.sqrt(4*4+5*5+6*6))

-- the length of a vector is its magnitude
local value = cc:compile(#v2)()
assert.equals(value, math.sqrt(4*4+5*5+6*6))

-- dot product
local value = cc:compile(cc:dot(v1,v2))()
assert.equals(value, 1*4 + 2*5 + 3*6)

local value = cc:compile(cc:dot(cc:vec(2,{4,6}), cc:vec(2,{-3,7})))()
assert.equals(value, 30)

local value = cc:compile(cc:dot(cc:vec(3,{3,-2,7}), cc:vec(3,{0,4,-1})))()
assert.equals(value, -15)

-- cross product
local value= cc:compile(cc:cross(cc:vec(3,{1,3,-4}), cc:vec(3,{2,-5,8})))()
assert.equals(value[0], 4)
assert.equals(value[1], -16)
assert.equals(value[2], -11)

-- 0 <= angle < 90 => dot product is positive
local value = cc:compile(cc:dot(cc:vec(2, {0,10}), cc:vec(2, {10,1})))()
assert(value > 0)

-- angle == 90 => dot product is zero
local value = cc:compile(cc:dot(cc:vec(2, {0,10}), cc:vec(2, {10,0})))()
assert(value == 0)

-- 90 < angle <= 180 => dot product is negative
local value = cc:compile(cc:dot(cc:vec(2, {0,10}), cc:vec(2, {10,-1})))()
assert(value < 0)

-- vector * scalar
local value = cc:compile(v1*2.5)()
assert.equals(value[0], 2.5)
assert.equals(value[1], 5.0)
assert.equals(value[2], 7.5)

-- scalar * vector
local value = cc:compile(1.5*v2)()
assert.equals(value[0], 6)
assert.equals(value[1], 7.5)
assert.equals(value[2], 9)

-- vector / scalar
local value = cc:compile(v2/4)()
assert.equals(value[0], 4/4)
assert.equals(value[1], 5/4)
assert.equals(value[2], 6/4)

-- normalize
local value = cc:compile(v2:normalize())()
local scale = 1 / math.sqrt(4*4 + 5*5 + 6*6)
assert.equals(value[0], 4*scale)
assert.equals(value[1], 5*scale)
assert.equals(value[2], 6*scale)

-- vector + vector
local value = cc:compile(v1+v2)()
assert.equals(value[0], 5)
assert.equals(value[1], 7)
assert.equals(value[2], 9)

-- vector - vector
local value = cc:compile(v1-v2)()
assert.equals(value[0], 1-4)
assert.equals(value[1], 2-5)
assert.equals(value[2], 3-6)

-- distance
local value = cc:compile(cc:distance(v1,v2))()
assert.equals(value, math.sqrt(27))

-- angle
local value = cc:compile(cc:angle(cc:vec(3,{2,1,3}), cc:vec(3,{6,3,9})))()
assert.equals(value, 0)

local value = cc:compile(cc:angle(cc:vec(2,{0,10}), cc:vec(2,{7,0})))()
assert.equals(value, math.pi/2)

-- angle is always positive
local value = cc:compile(cc:angle(cc:vec(2,{0,10}), cc:vec(2,{-7,0})))()
assert.equals(value, math.pi/2)

-- projection of one vector onto another
local value = cc:compile(cc:vec(2,{3,7}):project(cc:vec(2,{6,0})))()
assert.equals(value[0], 3)
assert.equals(value[1], 0)

local value = cc:compile(cc:vec(2,{3,7}):project(cc:vec(2,{0,-6})))()
assert.equals(value[0], 0)
assert.equals(value[1], 7)

-- matrix * matrix (2x2)
local m1 = cc:mat(2,2,{-3,5,0,1/2})
local m2 = cc:mat(2,2,{-7,4,2,6})
local value = cc:compile(m1*m2)()
assert.equals(value[0], 21)
assert.equals(value[1], -33)
assert.equals(value[2], -6)
assert.equals(value[3], 13)

-- matrix * matrix (3x3)
local m1 = cc:mat(3,3,{1,0,7,-5,-2,2,3,6,-4})
local m2 = cc:mat(3,3,{-8,7,2,6,0,4,1,-3,5})
local value = cc:compile(m1*m2)()
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
local value = cc:compile(m1*v2)()
assert.equals(value[0], 21)
assert.equals(value[1], -33)

-- vector * matrix
local v1 = cc:vec(3,{1,-5,3})
local m2 = cc:mat(3,3,{-8,7,2,6,0,4,1,-3,5})
local value = cc:compile(v1*m2)()
assert.equals(value[0], -37)
assert.equals(value[1], 18)
assert.equals(value[2], 31)

-- transpose
local m1 = cc:mat(3,3,{1,0,7,-5,-2,2,3,6,-4})
local value = cc:compile(m1:transpose())()
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
local value1,value2 = cc:compile((m1*m2):transpose(), m2:transpose()*m1:transpose())()
for i=0,8 do
   assert.equals(value1[i], value2[i])
end

-- rotate around arbitrary axis (unit vector)
local value = cc:compile(cc:vec(3,{8,9,-4})*cc:mat3_rotate(22*(math.pi/180), cc:vec(3,{1,-5,3}):normalize()))()
-- TODO: verify the result

-- minor matrix
local m = cc:mat(3,3,{-4,0,1,-3,2,4,3,-2,-1})
local value = cc:compile(m:minor(2,1))()
assert.equals(value[0], 0)
assert.equals(value[1], 1)
assert.equals(value[2], -2)
assert.equals(value[3], -1)

-- determinant
local m = cc:mat(3,3,{10,-2,3,0,-4,0,-3,1,2})
local value = cc:compile(m:det())()
assert.equals(value, -116)

local m1 = cc:mat(3,3,{1,0,7,-5,-2,2,3,6,-4})
local m2 = cc:mat(3,3,{-8,7,2,6,0,4,1,-3,5})

-- determinant of a matrix product = product of the determinants
local value1,value2 = cc:compile((m1*m2):det(),m1:det()*m2:det())()
assert.equals(value1, value2)

-- determinant of the transpose of a matrix = original determinant
local value1,value2 = cc:compile(m1:transpose():det(),m1:det())()
assert.equals(value1, value2)

-- inverse of matrix
local m = cc:mat(3,3,{-4,0,1,-3,2,4,3,-2,-1})

local value = cc:compile(m:inv())()
assert.equals(value[0], -1/4)
assert.equals(value[1], 1/12)
assert.equals(value[2], 1/12)
assert.equals(value[3], -3/8)
assert.equals(value[4], -1/24)
assert.equals(value[5], -13/24)
assert.equals(value[6], 0)
assert.equals(value[7], 1/3)
assert.equals(value[8], 1/3)

-- the inverse of the inverse is the original matrix
--
-- to account for the inaccuracies resulting from discrete floating
-- point calculations, we do not check for exact equality here
local function equals_enough(x,y)
   -- with 1e-16 it fails, I wonder why
   return math.abs(x-y) < 1e-15
end

local value = cc:compile(m:inv():inv())()
assert(equals_enough(value[0], -4))
assert(equals_enough(value[1], 0))
assert(equals_enough(value[2], 1))
assert(equals_enough(value[3], -3))
assert(equals_enough(value[4], 2))
assert(equals_enough(value[5], 4))
assert(equals_enough(value[6], 3))
assert(equals_enough(value[7], -2))
assert(equals_enough(value[8], -1))

-- input parameters
local factor = 2.5
local f = cc:compile(cc:vec(3,{8,1,5})*cc:num():input("factor"))
local value = f(factor)
assert.equals(value[0], 8*factor)
assert.equals(value[1], 1*factor)
assert.equals(value[2], 5*factor)

local term1 = 2.5
local term2 = 3.8
local f = cc:compile(cc:num():input("term1")-cc:num():input("term2"))
local value = f(term1, term2)
assert.equals(value, term1-term2)

-- modify input parameter (passed by reference)
local factor = 2.5
local input = cc:vec(3):input("v")
local f = cc:compile(cc:assign(input, input*factor))
local v = ffi.new("float[?]", 3*2, {8,1,5,4,9,3}) -- two vec3's
f(v+0)
assert.equals(v[0],8*factor)
assert.equals(v[1],1*factor)
assert.equals(v[2],5*factor)
f(v+0)
assert.equals(v[0],8*factor*factor)
assert.equals(v[1],1*factor*factor)
assert.equals(v[2],5*factor*factor)
f(v+3)
assert.equals(v[3],4*factor)
assert.equals(v[4],9*factor)
assert.equals(v[5],3*factor)

-- bool
local value = cc:compile(cc:lognot(cc:bool():input()))(true)
assert.equals(value, false)
local value = cc:compile(cc:lognot(cc:bool():input()))(false)
assert.equals(value, true)

-- assignment
local a = ffi.new("float[2]", {-3,5})
cc:compile(cc:assign(cc:vec(2):input(), cc:vec(2,{9,7})))(a)
assert.equals(a[0], 9)
assert.equals(a[1], 7)

-- conditional assignment
local input = cc:vec(2):input()
local f = cc:compile(cc:when(cc:gt(input:ref(2), 10),
                             cc:assign(input, cc:vec(2,{9,7})),
                             cc:assign(input, cc:vec(2,{-2,3}))))
local a = ffi.new("float[2]", {-3,5})
f(a)
assert.equals(a[0], -2)
assert.equals(a[1], 3)
local b = ffi.new("float[2]", {-3,11})
f(b)
assert.equals(b[0], 9)
assert.equals(b[1], 7)
