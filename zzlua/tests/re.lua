local re = require('re')

m = re.match("f(.)o", "barfoobar")
assert(m)
assert(m.stringcount==2)
assert(m[0]=="foo")
assert(m[1]=="o")
assert(m[2]==nil)
m = re.match("f(.)o", "barfoebar")
assert(m==nil)

m = re.match("\\s+$", "joo\n\nabc", 2)
assert(m==nil)
m = re.match("\\s+$", "joo\n\nabc", 3)
assert(m==nil)
m = re.match("\\s+", "joo\n\nabc", 3)
assert(m[0]=="\n\n")

assert(re.match("\\s+$", "hello, world!\n", 8))
assert(not re.match("\\s+$", "hello, world!\n", 8, re.ANCHORED))

-- compiled
r = re.compile("f(.)o")
m = r:match("barfoobar")
assert(m)
assert(m.stringcount==2)
assert(m[0]=="foo")
assert(m[1]=="o")
assert(m[2]==nil)
m = r:match("barfoebar")
assert(m==nil)
