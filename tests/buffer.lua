local buffer = require('buffer')
local assert = require('assert')
local sf = string.format

-- dynamic buffer starting out empty
local buf = buffer()
assert.type(buf:size(), "number", "buf:size()")
assert.equals(buf:size(), 0, "buf:size()")
assert.equals(buf:data(), "")

-- append
buf:append("hello")
assert.equals(buf:data(), "hello")
assert.equals(buf:size(), 5)
buf:append(", world!")
assert.equals(buf:size(), 13)
assert.equals(buf:data(), "hello, world!")

-- dynamic buffer with specified capacity
local buf2 = buffer(5)
assert(buf2:capacity()==5)
assert(buf2:size()==0)
assert(buf2:data()=="")
buf2:append("hell")
assert(buf2:capacity()==5)
assert(buf2:size()==4)
buf2:append("o, world!")
assert(buf2:capacity()==1024)
assert(buf2:size()==13)
assert(buf2:data()=="hello, world!")
assert(buf == buf2)

-- append only some part of data
buf2:append("\n\n\n\n\n\n", 2)
assert(buf2=="hello, world!\n\n")

-- dynamic buffer with initial data
local buf3 = buffer('   ')
assert(buf3:size()==3)
assert(buf3:capacity()==3)
assert(buf3:data()=='   ')

-- fill
buf3:fill(0x41)
assert(buf3=='AAA')

-- clear
buf3:clear()
assert(buf3=='\0\0\0')

-- dynamic buffer with initial data of specified size
local buf4 = buffer('abcdef', 3)
assert(buf4:size()==3)
assert(buf4:capacity()==3)
assert(buf4=='abc')

-- resize
local buf5 = buffer()
buf5:resize(2100) -- resize rounds up size to next multiple of 1024
assert(buf5:capacity()==3072)
buf5:resize(4000)
assert(buf5:capacity()==4096)
assert(buf5:size()==0)
for i=0,4095 do
   buf5:append(string.char(0x41+i%26))
end
assert(buf5:capacity()==4096)
assert(buf5:size()==4096)

-- data access
assert.equals(buf5[0], "A", "buf5[0]")
assert.equals(buf5:data(0,10), "ABCDEFGHIJ", "buf5:data(0,10)")
assert.equals(buf5:data(5,10), "FGHIJKLMNO", "buf5:data(5,10)")
buf5[2]="ABC"
assert.equals(buf5:data(0,10), "ABABCFGHIJ", "buf5:data(0,10)")
