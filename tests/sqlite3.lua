local sqlite = require('sqlite3')
local ffi = require('ffi')
local assert = require('assert')
local inspect = require('inspect')

ffi.cdef [[ int memcmp(const void *s1, const void *s2, size_t n); ]]

local function make_blob(size)
   local data = ffi.new("uint8_t[?]", size)
   for i=1,size do
      data[i-1] = math.random(0,255)
   end
   return data
end

-- when the database name is an empty string, SQLite creates a
-- temporary database which is automatically removed at close

local db = sqlite.open("")
db:exec([[
  CREATE TABLE data (
    f_integer INTEGER,
    f_real REAL,
    f_text TEXT,
    f_blob BLOB,
    f_null TEXT
  );
]])

-- indexed parameters

local stmt = db:prepare [[
  INSERT INTO data (f_integer, f_real, f_text, f_blob, f_null)
    VALUES (?,?,?,?,?)
]]

-- row #1 - binding nothing shall result in NULLs in all columns
assert.equals(stmt:step(), sqlite.SQLITE_DONE)
stmt:reset()

-- row #2 - bind_<type>(index, value[, length])
stmt:bind_double(2, 15.625) -- we can bind in any order
stmt:bind_int(1, 1234)
stmt:bind_text(3, "Hello, world!")
local blob1 = make_blob(128)
stmt:bind_blob(4, blob1, ffi.sizeof(blob1))
stmt:bind_null(5)
assert.equals(stmt:step(), sqlite.SQLITE_DONE)
stmt:reset()
stmt:clear_bindings() -- reset() doesn't clear the bindings

-- row #3 - bind(index, value[, length])
stmt:bind(1, 4321)
stmt:bind(2, 625.25)
stmt:bind(3, "árvíztűrő tükörfúrógép")
local blob2 = make_blob(128)
stmt:bind(4, blob2, ffi.sizeof(blob2))
assert.equals(stmt:step(), sqlite.SQLITE_DONE)
stmt:reset()
stmt:clear_bindings()

-- row #4 - bind { value, ... }
-- blobs cannot be bound this way, hence the nil for placeholder #4
stmt:bind { 8765, -65.05, "dancing galaxy", nil, nil }
assert.equals(stmt:step(), sqlite.SQLITE_DONE)
stmt:finalize()

-- named parameters

local stmt = db:prepare [[
  INSERT INTO data (f_integer, f_real, f_text, f_blob, f_null)
    VALUES (:f_integer, :f_real, :f_text, :f_blob, :f_null)
]]

-- row #5 - binding nothing shall result in NULLs in all columns
assert.equals(stmt:step(), sqlite.SQLITE_DONE)
stmt:reset()

-- row #6 - bind with named parameters
stmt:bind {
   f_integer = 5678,
   f_real = 125,
   f_text = "mahadeva",
   f_null = "loopus",
}
assert.equals(stmt:step(), sqlite.SQLITE_DONE)

-- row #7 - step(x) == reset() + clear_bindings() + bind(x) + step()
--                     + check that step() returns SQLITE_DONE
stmt:step {
   f_integer = 9876,
   f_real = -80.125,
   f_text = "brilliance"
}
stmt:finalize()

local stmt = db:prepare [[
  SELECT f_integer, f_real, f_text, f_blob, f_null FROM data
]]

-- row #1 - there should be NULLs in all columns
assert.equals(stmt:step(), sqlite.SQLITE_ROW)
assert.equals(stmt:column(1), nil)
assert.equals(stmt:column(2), nil)
assert.equals(stmt:column(3), nil)
assert.equals(stmt:column(4), nil)
assert.equals(stmt:column(5), nil)

-- row #2
assert.equals(stmt:step(), sqlite.SQLITE_ROW)

-- column_<type>(index)
assert.equals(stmt:column_int(1), 1234)
assert.equals(stmt:column_double(2), 15.625)
assert.equals(stmt:column_text(3), "Hello, world!")
local bytes, len = stmt:column_blob(4)
assert.equals(len, ffi.sizeof(blob1))
assert.equals(ffi.C.memcmp(bytes, blob1, len), 0)
-- NULL comes back as an empty string when read as text
assert.equals(stmt:column_text(5), "")

-- column(index)
assert.equals(stmt:column(1), 1234)
assert.equals(stmt:column(2), 15.625)
assert.equals(stmt:column(3), "Hello, world!")
local bytes, len = stmt:column(4)
assert.equals(len, ffi.sizeof(blob1))
assert.equals(ffi.C.memcmp(bytes, blob1, len), 0)
-- NULL comes back as nil when read with column()
assert.equals(stmt:column(5), nil)

-- column_<type>(name)
assert.equals(stmt:column_int("f_integer"), 1234)
assert.equals(stmt:column_double("f_real"), 15.625)
assert.equals(stmt:column_text("f_text"), "Hello, world!")
local bytes, len = stmt:column_blob("f_blob")
assert.equals(len, ffi.sizeof(blob1))
assert.equals(ffi.C.memcmp(bytes, blob1, len), 0)
assert.equals(stmt:column_text("f_null"), "")

-- column(name)
assert.equals(stmt:column("f_integer"), 1234)
assert.equals(stmt:column("f_real"), 15.625)
assert.equals(stmt:column("f_text"), "Hello, world!")
local bytes, len = stmt:column("f_blob")
assert.equals(len, ffi.sizeof(blob1))
assert.equals(ffi.C.memcmp(bytes, blob1, len), 0)
assert.equals(stmt:column("f_null"), nil)

-- row #3
assert.equals(stmt:step(), sqlite.SQLITE_ROW)
assert.equals(stmt:column_int(1), 4321)
assert.equals(stmt:column_double(2), 625.25)
assert.equals(stmt:column_text(3), "árvíztűrő tükörfúrógép")
local bytes, len = stmt:column_blob(4)
assert.equals(len, ffi.sizeof(blob2))
assert.equals(ffi.C.memcmp(bytes, blob2, len), 0)
assert.equals(stmt:column_text(5), "")

-- row #4 - row() returns a table indexed by column indices and names
assert.equals(stmt:step(), sqlite.SQLITE_ROW)
local row = stmt:row()
assert.equals(row, {
  [1] = 8765,
  [2] = -65.05,
  [3] = "dancing galaxy",
  [4] = nil,
  [5] = nil,
  f_integer = 8765,
  f_real = -65.05,
  f_text = "dancing galaxy",
  f_blob = nil,
  f_null = nil,
})

-- row #5 - all columns are NULL
assert.equals(stmt:step(), sqlite.SQLITE_ROW)
assert.equals(stmt:row(), {})

-- row #6
assert.equals(stmt:step(), sqlite.SQLITE_ROW)
assert.equals(stmt:row(), {
  [1] = 5678,
  [2] = 125,
  [3] = "mahadeva",
  [4] = nil,
  [5] = "loopus",
  f_integer = 5678,
  f_real = 125,
  f_text = "mahadeva",
  f_blob = nil,
  f_null = "loopus",
})

-- row #7
assert.equals(stmt:step(), sqlite.SQLITE_ROW)
local row = stmt:row()
assert.equals(row, {
  [1] = 9876,
  [2] = -80.125,
  [3] = "brilliance",
  f_integer = 9876,
  f_real = -80.125,
  f_text = "brilliance",
})

assert.equals(stmt:step(), sqlite.SQLITE_DONE)
stmt:finalize()

-- stmt:rows()

local stmt = db:prepare [[
  SELECT f_integer, f_real, f_text, f_blob, f_null FROM data
]]
assert.type(stmt.stmt, "cdata")
local count = 0
for row in stmt:rows() do
   count = count + (row['f_integer'] or 0)
end
-- stmt:rows() calls finalize() at the end
assert.type(stmt.stmt, "nil")
assert.equals(count, 1234+4321+8765+5678+9876)

db:close()
