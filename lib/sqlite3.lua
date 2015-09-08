local ffi = require('ffi')
local util = require('util')

ffi.cdef [[

enum {
  SQLITE_OK         =  0,   /* Successful result */
  SQLITE_ERROR      =  1,   /* SQL error or missing database */
  SQLITE_INTERNAL   =  2,   /* Internal logic error in SQLite */
  SQLITE_PERM       =  3,   /* Access permission denied */
  SQLITE_ABORT      =  4,   /* Callback routine requested an abort */
  SQLITE_BUSY       =  5,   /* The database file is locked */
  SQLITE_LOCKED     =  6,   /* A table in the database is locked */
  SQLITE_NOMEM      =  7,   /* A malloc() failed */
  SQLITE_READONLY   =  8,   /* Attempt to write a readonly database */
  SQLITE_INTERRUPT  =  9,   /* Operation terminated by sqlite3_interrupt()*/
  SQLITE_IOERR      = 10,   /* Some kind of disk I/O error occurred */
  SQLITE_CORRUPT    = 11,   /* The database disk image is malformed */
  SQLITE_NOTFOUND   = 12,   /* Unknown opcode in sqlite3_file_control() */
  SQLITE_FULL       = 13,   /* Insertion failed because database is full */
  SQLITE_CANTOPEN   = 14,   /* Unable to open the database file */
  SQLITE_PROTOCOL   = 15,   /* Database lock protocol error */
  SQLITE_EMPTY      = 16,   /* Database is empty */
  SQLITE_SCHEMA     = 17,   /* The database schema changed */
  SQLITE_TOOBIG     = 18,   /* String or BLOB exceeds size limit */
  SQLITE_CONSTRAINT = 19,   /* Abort due to constraint violation */
  SQLITE_MISMATCH   = 20,   /* Data type mismatch */
  SQLITE_MISUSE     = 21,   /* Library used incorrectly */
  SQLITE_NOLFS      = 22,   /* Uses OS features not supported on host */
  SQLITE_AUTH       = 23,   /* Authorization denied */
  SQLITE_FORMAT     = 24,   /* Auxiliary database format error */
  SQLITE_RANGE      = 25,   /* 2nd parameter to sqlite3_bind out of range */
  SQLITE_NOTADB     = 26,   /* File opened that is not a database file */
  SQLITE_NOTICE     = 27,   /* Notifications from sqlite3_log() */
  SQLITE_WARNING    = 28,   /* Warnings from sqlite3_log() */
  SQLITE_ROW        = 100,  /* sqlite3_step() has another row ready */
  SQLITE_DONE       = 101  /* sqlite3_step() has finished executing */
};

enum {
  SQLITE_INTEGER = 1,
  SQLITE_FLOAT   = 2,
  SQLITE_TEXT    = 3,
  SQLITE_BLOB    = 4,
  SQLITE_NULL    = 5,
};

typedef int64_t sqlite3_int64;
typedef uint64_t sqlite3_uint64;

typedef struct sqlite3 sqlite3;

int sqlite3_open(
  const char *filename,   /* Database filename (UTF-8) */
  sqlite3 **ppDb          /* OUT: SQLite db handle */
);
int sqlite3_open_v2(
  const char *filename,   /* Database filename (UTF-8) */
  sqlite3 **ppDb,         /* OUT: SQLite db handle */
  int flags,              /* Flags */
  const char *zVfs        /* Name of VFS module to use */
);
sqlite3_int64 sqlite3_last_insert_rowid(sqlite3*);
int sqlite3_changes(sqlite3*);
void sqlite3_interrupt(sqlite3*);
int sqlite3_close_v2(sqlite3*);

typedef struct sqlite3_stmt sqlite3_stmt;

typedef void (*sqlite3_destructor_type)(void*);

static const int SQLITE_STATIC = 0;
static const int SQLITE_TRANSIENT = -1;

int sqlite3_prepare_v2(
  sqlite3 *db,            /* Database handle */
  const char *zSql,       /* SQL statement, UTF-8 encoded */
  int nByte,              /* Maximum length of zSql in bytes. */
  sqlite3_stmt **ppStmt,  /* OUT: Statement handle */
  const char **pzTail     /* OUT: Pointer to unused portion of zSql */
);
int sqlite3_stmt_busy(sqlite3_stmt*);
int sqlite3_bind_blob(sqlite3_stmt*, int, const void*, int n, void(*)(void*));
int sqlite3_bind_double(sqlite3_stmt*, int, double);
int sqlite3_bind_int(sqlite3_stmt*, int, int);
int sqlite3_bind_null(sqlite3_stmt*, int);
int sqlite3_bind_text(sqlite3_stmt*, int, const char*, int n, void(*)(void*));
int sqlite3_bind_zeroblob(sqlite3_stmt*, int, int n);
int sqlite3_column_count(sqlite3_stmt *pStmt);
const char *sqlite3_column_database_name(sqlite3_stmt*,int);
const char *sqlite3_column_table_name(sqlite3_stmt*,int);
const char *sqlite3_column_origin_name(sqlite3_stmt*,int);
const char *sqlite3_column_decltype(sqlite3_stmt*,int);
int sqlite3_bind_parameter_index(sqlite3_stmt*, const char *zName);
int sqlite3_step(sqlite3_stmt*);
int sqlite3_data_count(sqlite3_stmt *pStmt);
const void *sqlite3_column_blob(sqlite3_stmt*, int iCol);
int sqlite3_column_bytes(sqlite3_stmt*, int iCol);
double sqlite3_column_double(sqlite3_stmt*, int iCol);
int sqlite3_column_int(sqlite3_stmt*, int iCol);
const unsigned char *sqlite3_column_text(sqlite3_stmt*, int iCol);
int sqlite3_column_type(sqlite3_stmt*, int iCol);
int sqlite3_reset(sqlite3_stmt *pStmt);
int sqlite3_clear_bindings(sqlite3_stmt*);
int sqlite3_finalize(sqlite3_stmt *pStmt);

typedef struct sqlite3_blob sqlite3_blob;

int sqlite3_blob_open(
  sqlite3*,
  const char *zDb,
  const char *zTable,
  const char *zColumn,
  sqlite3_int64 iRow,
  int flags,
  sqlite3_blob **ppBlob
);
int sqlite3_blob_bytes(sqlite3_blob *);
int sqlite3_blob_read(sqlite3_blob *, void *Z, int N, int iOffset);
int sqlite3_blob_write(sqlite3_blob *, const void *z, int n, int iOffset);
int sqlite3_blob_close(sqlite3_blob *);

int sqlite3_errcode(sqlite3 *db);
int sqlite3_extended_errcode(sqlite3 *db);
const char *sqlite3_errstr(int);
const char *sqlite3_errmsg(sqlite3*);

int sqlite3_complete(const char *sql);

]]

local sqlite3 = ffi.load("sqlite3")

local Stmt_mt = {}

function Stmt_mt:bind_int(index, value)
   util.check_ok("sqlite3_bind_int", 0,
                 sqlite3.sqlite3_bind_int(self.stmt, index, value))
end

function Stmt_mt:bind_double(index, value)
   local rv = sqlite3.sqlite3_bind_double(self.stmt, index, value)
   if rv ~= sqlite3.SQLITE_OK then
      ef("sqlite3_bind_double(%d, %s) failed: %s", index, value, self.db:errmsg())
   end
end

function Stmt_mt:bind_text(index, value)
   util.check_ok("sqlite3_bind_text", 0,
                 sqlite3.sqlite3_bind_text(self.stmt, index,
                                           value, #value,
                                           ffi.cast("sqlite3_destructor_type",
                                                    sqlite3.SQLITE_STATIC)))
end

function Stmt_mt:bind_blob(index, ptr, len)
   util.check_ok("sqlite3_bind_blob", 0,
                 sqlite3.sqlite3_bind_blob(self.stmt, index,
                                           ptr, len,
                                           ffi.cast("sqlite3_destructor_type",
                                                    sqlite3.SQLITE_STATIC)))
end

function Stmt_mt:bind_null(index)
   util.check_ok("sqlite3_bind_null", 0,
                 sqlite3.sqlite3_bind_null(self.stmt, index))
end

function Stmt_mt:bind_row(row)
   if #row == 0 then
      -- named parameters
      for k,v in pairs(row) do
         self:bind_named(k,v)
      end
   else
      -- indexed parameters
      for i,v in ipairs(row) do
         self:bind(i,v)
      end
   end
end

function Stmt_mt:bind_named(colname, value, length)
   if not colname:match("^[?:@]") then
      colname = ":"..colname
   end
   local index = sqlite3.sqlite3_bind_parameter_index(self.stmt, colname)
   if index == 0 then
      ef("invalid parameter name: %s", colname)
   end
   self:bind(index, value, length)
end

function Stmt_mt:bind(index, value, length)
   if type(index)=="table" then
      self:bind_row(index)
   elseif type(index)=="string" then
      self:bind_named(index, value, length)
   elseif type(index)=="number" then
      if value==nil then
         self:bind_null(index)
      elseif type(value)=="number" then
         self:bind_double(index, value)
      elseif type(value)=="string" then
         self:bind_text(index, value)
      elseif type(value)=="cdata" then
         if type(length)~="number" then
            ef("binding a blob needs a length argument")
         end
         self:bind_blob(index, value, length)
      else
         ef("cannot bind value: %s (%s)", value, type(value))
      end
   else
      ef("invalid index: %s", index)
   end
end

function Stmt_mt:column_count()
   return sqlite3.sqlite3_column_count(self.stmt)
end

function Stmt_mt:data_count()
   return sqlite3.sqlite3_data_count(self.stmt)
end

function Stmt_mt:get_column_index(name)
   if not self.column_indices then
      local column_count = self:column_count()
      if column_count == 0 then
         ef("result set is empty")
      else
         self.column_indices = {}
         for i=1,column_count do
            local origin_name = sqlite3.sqlite3_column_origin_name(self.stmt, i-1)
            if origin_name == nil then
               ef("cannot determine column origin name")
            end
            self.column_indices[ffi.string(origin_name)] = i
         end
      end
   end
   local index = self.column_indices[name]
   if not index then
      ef("invalid column name: %s", name)
   end
   return index
end

function Stmt_mt:get_column_name(index)
   if not self.column_names then
      local column_count = self:column_count()
      if column_count == 0 then
         ef("result set is empty")
      else
         self.column_names = {}
         for i=1,column_count do
            local origin_name = sqlite3.sqlite3_column_origin_name(self.stmt, i-1)
            if origin_name == nil then
               ef("cannot determine column origin name")
            end
            self.column_names[i] = ffi.string(origin_name)
         end
      end
   end
   local name = self.column_names[index]
   if not name then
      ef("invalid column index: %d", index)
   end
   return name
end

function Stmt_mt:column_int(index)
   if type(index)=="string" then
      index = self:get_column_index(index)
   end
   return sqlite3.sqlite3_column_int(self.stmt, index-1)
end

function Stmt_mt:column_double(index)
   if type(index)=="string" then
      index = self:get_column_index(index)
   end
   return sqlite3.sqlite3_column_double(self.stmt, index-1)
end

function Stmt_mt:column_text(index)
   if type(index)=="string" then
      index = self:get_column_index(index)
   end
   local n_bytes = sqlite3.sqlite3_column_bytes(self.stmt, index-1)
   return ffi.string(sqlite3.sqlite3_column_text(self.stmt, index-1), n_bytes)
end

function Stmt_mt:column_blob(index)
   if type(index)=="string" then
      index = self:get_column_index(index)
   end
   local n_bytes = sqlite3.sqlite3_column_bytes(self.stmt, index-1)
   return sqlite3.sqlite3_column_blob(self.stmt, index-1), n_bytes
end

function Stmt_mt:column(index)
   if type(index)=="string" then
      index = self:get_column_index(index)
   end
   local coltype = sqlite3.sqlite3_column_type(self.stmt, index-1)
   if coltype == sqlite3.SQLITE_INTEGER then
      return self:column_int(index)
   elseif coltype == sqlite3.SQLITE_FLOAT then
      return self:column_double(index)
   elseif coltype == sqlite3.SQLITE_TEXT then
      return self:column_text(index)
   elseif coltype == sqlite3.SQLITE_BLOB then
      return self:column_blob(index)
   elseif coltype == sqlite3.SQLITE_NULL then
      return nil
   else
      ef("Unsupported column type: %d", coltype)
   end
end

function Stmt_mt:row()
   local row = {}
   for i=1,self:data_count() do
      local value = self:column(i)
      row[i] = value
      local name = self:get_column_name(i)
      row[name] = value
   end
   return row
end

function Stmt_mt:step(x, ...)
   if x then
      self:reset()
      self:clear_bindings()
      self:bind(x, ...)
      local rv = self:step()
      if rv ~= sqlite3.SQLITE_DONE then
         ef("sqlite3_step() failed: %d", rv)
      end
   else
      return sqlite3.sqlite3_step(self.stmt)
   end
end

function Stmt_mt:rows()
   local function next()
      local rv = self:step()
      if rv == sqlite3.SQLITE_ROW then
         return self:row()
      elseif rv == sqlite3.SQLITE_DONE then
         self:finalize()
         return nil
      else
         ef(self.db:errmsg())
      end
   end
   return next
end

function Stmt_mt:reset()
   util.check_ok("sqlite3_reset", 0, sqlite3.sqlite3_reset(self.stmt))
end

function Stmt_mt:clear_bindings()
   util.check_ok("sqlite3_clear_bindings", 0,
                 sqlite3.sqlite3_clear_bindings(self.stmt))
end

function Stmt_mt:finalize()
   if self.stmt then
      util.check_ok("sqlite3_finalize", 0, sqlite3.sqlite3_finalize(self.stmt))
      self.stmt = nil
   end
end

Stmt_mt.__index = Stmt_mt
Stmt_mt.__gc = Stmt_mt.finalize

local Db_mt = {}

function Db_mt:errmsg()
   return ffi.string(sqlite3.sqlite3_errmsg(self.db))
end

function Db_mt:prepare(sql)
   local ppstmt = ffi.new("sqlite3_stmt*[1]")
   local rv = sqlite3.sqlite3_prepare_v2(self.db, sql, #sql, ppstmt, nil)
   if rv ~= 0 then
      ef("sqlite3_prepare_v2() failed: %s", self:errmsg())
   end
   local stmt = { stmt = ppstmt[0], db = self }
   return setmetatable(stmt, Stmt_mt)
end

function Db_mt:exec(sql)
   local stmt = self:prepare(sql)
   local rv = stmt:step()
   if rv ~= sqlite3.SQLITE_DONE then
      ef("SQL query failed: %s\n%s", self:errmsg(), sql)
   end
   stmt:finalize()
end

function Db_mt:close()
   if self.db then
      util.check_ok("sqlite3_close_v2", 0, sqlite3.sqlite3_close_v2(self.db))
      self.db = nil
   end
end

Db_mt.__index = Db_mt
Db_mt.__gc = Db_mt.close

local M = {}

function M.open(filename)
   local ppdb = ffi.new("sqlite3*[1]")
   local rv = sqlite3.sqlite3_open(filename, ppdb)
   if rv ~= 0 then
      if ppdb[0] ~= nil then
         local errmsg = ffi.string(sqlite3.sqlite3_errmsg(ppdb[0]))
         sqlite3.sqlite3_close_v2(ppdb[0])
         ef("sqlite3_open_v2 failed: %s", errmsg)
      else
         ef("sqlite3_open_v2 failed: cannot allocate sqlite3 structure")
      end
   end
   local self = { db = ppdb[0] }
   return setmetatable(self, Db_mt)
end

return setmetatable(M, { __index = sqlite3 })
