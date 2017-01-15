local ffi = require('ffi')
local util = require('util')

local M = {}

-- Compiler

local function CodeGen()
   local self = {}
   local items = {}
   local function call(self, code)
      if code and #code > 0 then
         table.insert(items, code)
      end
   end
   function self:code()
      return table.concat(items, "\n")
   end
   return setmetatable(self, { __call = call })
end

local next_struct_id = util.Counter()

function M.Compiler(opts)
   opts = opts or {}

   local ctx = {
      numtype = opts.numtype or 'float'
   }

   local node_counter = util.Counter()

   local function is_node(x)
      return type(x)=="table" and x.type
   end

   local function is_node_with_type(x, t)
      return is_node(x) and x.type==t
   end

   local function is_num(x)
      return type(x)=="number" or is_node_with_type(x, "num")
   end

   local function is_bool(x)
      return type(x)=="boolean" or is_node_with_type(x, "bool")
   end

   local function is_vec(x)
      return is_node_with_type(x, "vec")
   end

   local function is_mat(x)
      return is_node_with_type(x, "mat")
   end

   local function is_scalar(x)
      return is_num(x) or is_bool(x)
   end

   function ctx:node(t)
      local self = {
         id = node_counter(),
         type = t,
         deps = {},
         users = {},
      }
      function self:depends(items)
         assert(type(items)=="table")
         assert(#self.deps==0)
         for _,x in ipairs(items) do
            if is_node(x) then
               table.insert(self.deps, x)
               table.insert(x.users, self)
            end
         end
         return self
      end
      function self:invoke(visitor, recursive)
         if recursive then
            for _,node in ipairs(self.deps) do
               node:invoke(visitor, recursive)
            end
         end
         visitor(self)
      end
      function self:emit_code(codegen)
         -- to be implemented downstream
      end
      return self
   end

   function ctx:value(t)
      local self = ctx:node(t)
      self.is_value = true
      self.is_param = false
      self.param_kind = nil -- nil/input/output
      self.param_name = nil -- nil means auto-generated
      function self:param(name, kind)
         if name then
            self.param_name = name
         end
         self.param_kind = kind or "output"
         self.is_param = true
         return self
      end
      function self:input(name)
         return self:param(name, "input")
      end
      function self:output(name)
         return self:param(name, "output")
      end
      function self:name()
         return self.param_name or sf('%s_%d', t, self.id)
      end
      function self:var()
         return self:name()
      end
      function self:expr()
         return self:var()
      end
      function self:requires_var()
         return #self.users > 1 or not is_scalar(self)
      end
      function self:emit_data(codegen)
         codegen(sf("local %s", self:name()))
      end
      function self:emit_code(codegen)
         codegen(sf("%s = %s", self:var(), self:expr()))
      end
      return self
   end

   local function is_value(x)
      return is_node(x) and x.is_value
   end

   function ctx:stmt(t)
      local self = ctx:node(t)
      self.is_stmt = true
      return self
   end

   local function is_stmt(x)
      return is_node(x) and x.is_stmt
   end

   local function source_of(x)
      if is_value(x) then
         if #x.users > 1 then
            return x:var()
         else
            return sf("(%s)", x:expr())
         end
      elseif type(x)=="number" or type(x)=="boolean" then
         return tostring(x)
      elseif type(x)=="string" then
         return x
      else
         return "nil"
      end
   end

   local function sources_of(items, sep)
      local values = {}
      for _,item in ipairs(items) do
         table.insert(values, source_of(item))
      end
      if sep then
         values = table.concat(values, sep)
      end
      return values
   end

   local num_mt = {}

   function num_mt.__add(n1, n2)
      return ctx:binop("+", n1, n2)
   end

   function num_mt.__sub(n1, n2)
      return ctx:binop("-", n1, n2)
   end

   function num_mt.__mul(n1, n2)
      return ctx:binop("*", n1, n2)
   end

   function num_mt.__div(n1, n2)
      return ctx:binop("/", n1, n2)
   end

   function ctx:num()
      local self = ctx:value("num")
      return setmetatable(self, num_mt)
   end

   function ctx:bool()
      local self = ctx:value("bool")
      return self
   end

   function ctx:fn(func_name, ...)
      local params = {...}
      local self = ctx:num():depends(params)
      function self:expr()
         return sf("%s(%s)", func_name, sources_of(params,','))
      end
      return self
   end

   local function def_math_fn(name)
      ctx[name] = function(ctx, ...)
         return ctx:fn("math." .. name, ...)
      end
   end

   def_math_fn("abs")
   def_math_fn("acos")
   def_math_fn("asin")
   def_math_fn("atan")
   def_math_fn("atan2")
   def_math_fn("ceil")
   def_math_fn("cos")
   def_math_fn("cosh")
   def_math_fn("exp")
   def_math_fn("floor")
   def_math_fn("fmod")
   def_math_fn("frexp")
   def_math_fn("ldexp")
   def_math_fn("log")
   def_math_fn("log10")
   def_math_fn("max")
   def_math_fn("min")
   def_math_fn("pow")
   def_math_fn("rad")
   def_math_fn("random")
   def_math_fn("sin")
   def_math_fn("sinh")
   def_math_fn("sqrt")
   def_math_fn("tan")
   def_math_fn("tanh")

   function ctx:binop(op, arg1, arg2)
      local self = ctx:num():depends{arg1, arg2}
      function self:expr()
         return sf("%s %s %s", source_of(arg1), op, source_of(arg2))
      end
      return self
   end

   function ctx:add(arg1, arg2)
      return ctx:binop("+", arg1, arg2)
   end

   function ctx:sub(arg1, arg2)
      return ctx:binop("-", arg1, arg2)
   end

   function ctx:mul(arg1, arg2)
      return ctx:binop("*", arg1, arg2)
   end

   function ctx:div(arg1, arg2)
      return ctx:binop("/", arg1, arg2)
   end

   -- vector

   local vec_mt = {}

   function vec_mt:index(i)
      if self.is_param then
         -- input and output vectors are cdata
         -- their indexing is 0-based
         return i-1
      else
         return i
      end
   end

   function vec_mt:ref(i)
      return sf("%s[%d]", self:var(), self:index(i))
   end

   function vec_mt.__unm(v)
      local self = ctx:vec(v.size):depends{v}
      function self:emit_code(codegen)
         for i=1,self.size do
            codegen(sf("%s = -%s", self:ref(i), v:ref(i)))
         end
      end
      return self
   end

   function vec_mt.binop(lhs, rhs, op)
      assert(is_vec(lhs))
      assert(is_vec(rhs))
      assert(lhs.size == rhs.size)
      local self = ctx:vec(lhs.size):depends{lhs, rhs}
      function self:emit_code(codegen)
         for i=1,self.size do
            codegen(sf("%s = %s %s %s",
                       self:ref(i),
                       lhs:ref(i),
                       op,
                       rhs:ref(i)))
         end
      end
      return self
   end

   function vec_mt.__add(lhs, rhs)
      return vec_mt.binop(lhs, rhs, '+')
   end

   function vec_mt.__sub(lhs, rhs)
      return vec_mt.binop(lhs, rhs, '-')
   end

   function vec_mt.__mul(lhs, rhs)
      if is_num(lhs) then
         lhs,rhs = rhs,lhs
      end
      assert(is_vec(lhs))
      if is_num(rhs) then
         local self = ctx:vec(lhs.size):depends{lhs, rhs}
         function self:emit_code(codegen)
            codegen("do")
            codegen(sf("local factor = %s", source_of(rhs)))
            for i=1,self.size do
               codegen(sf("%s = %s * factor", self:ref(i), lhs:ref(i)))
            end
            codegen("end")
         end
         return self
      elseif is_mat(rhs) then
         assert(lhs.size==rhs.rows)
         local self = ctx:vec(rhs.cols):depends{lhs, rhs}
         function self:emit_code(codegen)
            for x=1,self.size do
               local terms = {}
               for i=1,lhs.size do
                  table.insert(terms, sf("%s*%s",
                                         lhs:ref(i),
                                         rhs:ref(x,i)))
               end
               codegen(sf("%s = %s",
                          self:ref(x),
                          table.concat(terms,'+')))
            end
         end
         return self
      else
         ef("invalid operand: %s", rhs)
      end
   end

   function vec_mt.__div(lhs, rhs)
      assert(is_vec(lhs))
      assert(is_num(rhs))
      return lhs * ctx:div(1, rhs)
   end

   function vec_mt.__len(v)
      local self = ctx:num():depends{v}
      function self:expr()
         local terms = {}
         for i=1,v.size do
            table.insert(terms, sf("%s*%s", v:ref(i), v:ref(i)))
         end
         return sf("math.sqrt(%s)", table.concat(terms,'+'))
      end
      return self
   end

   function vec_mt:mag()
      return #self
   end

   function vec_mt.normalize(v)
      return v / #v
   end

   function vec_mt:project(v)
      -- calculate projection of this vector onto v
      local dot = ctx:dot(self, v)
      local v_mag = #v
      local sq = v_mag * v_mag
      return v * (dot / sq)
   end

   vec_mt.__index = vec_mt

   function ctx:vec(size, init)
      local elements = {}
      assert(type(size)=="number")
      init = init or 0
      if init then
         if type(init)=="number" then
            for i=1,size do
               elements[i] = init
            end
         elseif type(init)=="table" then
            assert(#init==size)
            elements = init
         else
            ef("invalid vector initializer: %s", init)
         end
      end
      local self = ctx:value("vec")
      self.size = size
      function self:emit_data(codegen)
         if not self.is_param then
            codegen(sf("local %s = {%s}",
                       self:name(),
                       sources_of(elements, ',')))
         elseif self.param_kind == "output" then
            codegen(sf("local %s = ffi.new('%s[%d]')",
                       self:name(),
                       ctx.numtype,
                       self.size))
         end
      end
      function self:emit_code(codegen)
         if self.param_kind == "output" and #elements > 0 then
            for i=1,self.size do
               codegen(sf("%s = %s",
                          self:ref(i),
                          source_of(elements[i])))
            end
         end
      end
      return setmetatable(self, vec_mt)
   end

   function ctx:dot(lhs, rhs)
      assert(is_vec(lhs))
      assert(is_vec(rhs))
      assert(lhs.size==rhs.size)
      local self = ctx:num():depends{lhs, rhs}
      function self:expr()
         local terms = {}
         for i=1,lhs.size do
            table.insert(terms, sf("%s*%s", lhs:ref(i), rhs:ref(i)))
         end
         return table.concat(terms,'+')
      end
      return self
   end

   function ctx:cross(lhs, rhs)
      assert(is_vec(lhs))
      assert(is_vec(rhs))
      assert(lhs.size==rhs.size)
      assert(lhs.size==3)
      local self = ctx:vec(lhs.size):depends{lhs, rhs}
      local function subexpr(i)
         if i == 1 then
            return sf("%s*%s - %s*%s",
                      lhs:ref(2), rhs:ref(3),
                      lhs:ref(3), rhs:ref(2))
         elseif i == 2 then
            return sf("%s*%s - %s*%s",
                      lhs:ref(3), rhs:ref(1),
                      lhs:ref(1), rhs:ref(3))
         elseif i == 3 then
            return sf("%s*%s - %s*%s",
                      lhs:ref(1), rhs:ref(2),
                      lhs:ref(2), rhs:ref(1))
         else
            ef("bad index")
         end
      end
      function self:emit_code(codegen)
         for i=1,self.size do
            codegen(sf("%s = %s", self:ref(i), subexpr(i)))
         end
      end
      return self
   end

   function ctx:distance(v1, v2)
      return #(v2-v1)
   end

   function ctx:angle(v1, v2)
      return ctx:acos(ctx:dot(v1,v2) / (#v1*#v2))
   end

   -- matrix

   local mat_mt = {}

   function mat_mt:index(x, y)
      -- matrix elements are stored in column-major order
      local i = (x - 1) * self.rows + y
      if self.is_param then
         -- input and output matrices are cdata
         -- their indexing is 0-based
         return i-1
      else
         return i
      end
   end

   function mat_mt:ref(x, y)
      return sf("%s[%d]", self:var(), self:index(x, y))
   end

   function mat_mt.__mul(lhs, rhs)
      if is_num(lhs) then
         lhs,rhs = rhs,lhs
      end
      if is_num(rhs) then
         local self = ctx:mat(lhs.cols, lhs.rows):depends{lhs, rhs}
         function self:emit_code(codegen)
            codegen("do")
            codegen(sf("local factor = %s", source_of(rhs)))
            for x=1,self.cols do
               for y=1,self.rows do
                  codegen(sf("%s = %s * factor",
                             self:ref(x,y),
                             lhs:ref(x,y)))
               end
            end
            codegen("end")
         end
         return self
      elseif is_mat(rhs) then
         assert(lhs.cols==rhs.rows)
         local self = ctx:mat(rhs.cols, lhs.rows):depends{lhs, rhs}
         function self:emit_code(codegen)
            for x=1,self.cols do
               for y=1,self.rows do
                  local terms = {}
                  for i=1,lhs.cols do
                     table.insert(terms, sf("%s*%s",
                                            lhs:ref(i,y),
                                            rhs:ref(x,i)))
                  end
                  codegen(sf("%s = %s",
                             self:ref(x,y),
                             table.concat(terms,'+')))
               end
            end
         end
         return self
      elseif is_vec(rhs) then
         assert(lhs.cols==rhs.size)
         local self = ctx:vec(lhs.rows):depends{lhs, rhs}
         function self:emit_code(codegen)
            for y=1,self.size do
               local terms = {}
               for i=1,lhs.cols do
                  table.insert(terms, sf("%s*%s",
                                         lhs:ref(i,y),
                                         rhs:ref(i)))
               end
               codegen(sf("%s = %s",
                          self:ref(y),
                          table.concat(terms,'+')))
            end
         end
         return self
      else
         ef("invalid operand: %s", rhs)
      end
   end

   function mat_mt.__div(lhs, rhs)
      assert(is_mat(lhs))
      assert(is_num(rhs))
      return lhs * ctx:div(1, rhs)
   end

   function mat_mt.extend(m, size)
      assert(type(size)=="number")
      assert(size >= m.cols)
      assert(size >= m.rows)
      local self = ctx:mat_identity(size):depends{m}
      local super_emit_code = self.emit_code
      function self:emit_code(codegen)
         super_emit_code(self, codegen)
         for x=1,m.cols do
            for y=1,m.rows do
               codegen(sf("%s = %s", self:ref(x,y), m:ref(x,y)))
            end
         end
      end
      return self
   end

   function mat_mt.transpose(m)
      local self = ctx:mat(m.rows, m.cols):depends{m}
      function self:emit_code(codegen)
         for x=1,self.cols do
            for y=1,self.rows do
               codegen(sf("%s = %s",
                          self:ref(x,y),
                          m:ref(y,x)))
            end
         end
      end
      return self
   end

   function mat_mt.minor(m, x0, y0)
      assert(m.cols >= 2)
      assert(m.rows >= 2)
      assert(is_num(x0))
      assert(is_num(y0))
      local self = ctx:mat(m.rows-1, m.cols-1):depends{m}
      function self:emit_code(codegen)
         for x=1,self.cols do
            local mx = (x >= x0) and (x+1) or x
            for y=1,self.rows do
               local my = (y >= y0) and (y+1) or y
               codegen(sf("%s=%s", self:ref(x, y), m:ref(mx, my)))
            end
         end
      end
      return self
   end

   function mat_mt.cofactor(m, x, y)
      local sign = ((x+y) % 2 == 0) and 1 or -1
      return m:minor(x,y):det() * sign
   end

   function mat_mt.det(m)
      assert(m.cols==m.rows)
      local self
      if m.rows == 2 then
         self = ctx:num():depends{m}
         function self:expr()
            return sf("%s * %s - %s * %s",
                      m:ref(1,1), m:ref(2,2),
                      m:ref(2,1), m:ref(1,2))
         end
      elseif m.rows > 2 then
         local cofactors = {}
         for x=1,m.cols do
            table.insert(cofactors, m:cofactor(x,1))
         end
         self = ctx:num():depends{m, unpack(cofactors)}
         function self:expr()
            local terms = {}
            for x=1,m.cols do
               table.insert(terms, sf("%s * %s",
                                      m:ref(x,1),
                                      source_of(cofactors[x])))
            end
            return table.concat(terms,' + ')
         end
      else
         ef("invalid matrix size: %s, must be >= 2 to calculate determinant", m.rows)
      end
      return self
   end

   function mat_mt.cofactors(m)
      assert(m.cols==m.rows)
      local cofactors = {}
      for x=1,m.cols do
         for y=1,m.rows do
            table.insert(cofactors, m:cofactor(x,y))
         end
      end
      local self = ctx:mat(m.cols, m.rows):depends{m, unpack(cofactors)}
      function self:emit_code(codegen)
         for x=1,self.cols do
            for y=1,self.rows do
               local i = (x - 1) * self.rows + y
               codegen(sf("%s = %s",
                          self:ref(x,y),
                          source_of(cofactors[i])))
            end
         end
      end
      return self
   end

   function mat_mt.adj(m)
      return m:cofactors():transpose()
   end

   function mat_mt.inv(m)
      return m:adj() / m:det()
   end

   mat_mt.__index = mat_mt

   function ctx:mat(cols, rows, init)
      local elements = {}
      assert(type(cols)=="number")
      rows = rows or cols
      assert(type(rows)=="number")
      local size = cols * rows
      init = init or 0
      if init then
         if type(init)=="number" then
            for i=1,size do
               elements[i] = init
            end
         elseif type(init)=="table" then
            assert(#init==size)
            elements = init
         else
            ef("invalid matrix initializer: %s", init)
         end
      end
      local self = ctx:value("mat")
      self.cols = cols
      self.rows = rows
      function self:emit_data(codegen)
         if not self.is_param then
            codegen(sf("local %s = {%s}",
                       self:name(),
                       sources_of(elements, ',')))
         else
            codegen(sf("local %s = ffi.new('%s[%d]')",
                       self:name(),
                       ctx.numtype,
                       size))
         end
      end
      function self:emit_code(codegen)
         if self.param_kind == "output" and #elements > 0 then
            for x=1,cols do
               for y=1,rows do
                  local i = (x-1)*rows + y
                  codegen(sf("%s[%d]=%s", self:var(), i-1, source_of(elements[i])))
               end
            end
         end
      end
      return setmetatable(self, mat_mt)
   end

   function ctx:mat_zero(size)
      return ctx:mat(size, size, 0)
   end

   function ctx:mat_identity(size)
      local elements = {}
      for x=1,size do
         for y=1,size do
            elements[(x-1)*size+y] = (x==y and 1 or 0)
         end
      end
      return ctx:mat(size, size, elements)
   end

   function ctx:mat2_rotate(angle)
      local self = ctx:mat(2,2):depends{angle}
      function self:emit_code(codegen)
         codegen "do"
         codegen(sf("local cos = math.cos(%s)", source_of(angle)))
         codegen(sf("local sin = math.sin(%s)", source_of(angle)))
         codegen(sf("%s = cos", self:ref(1,1)))
         codegen(sf("%s =-sin", self:ref(1,2)))
         codegen(sf("%s = sin", self:ref(2,1)))
         codegen(sf("%s = cos", self:ref(2,2)))
         codegen "end"
      end
      return self
   end

   function ctx:mat3_rotate_x(angle)
      local self = ctx:mat(3,3):depends{angle}
      function self:emit_code(codegen)
         codegen "do"
         codegen(sf("local cos = math.cos(%s)", source_of(angle)))
         codegen(sf("local sin = math.sin(%s)", source_of(angle)))
         codegen(sf("%s = 1",   self:ref(1,1)))
         codegen(sf("%s = 0",   self:ref(1,2)))
         codegen(sf("%s = 0",   self:ref(1,3)))
         codegen(sf("%s = 0",   self:ref(2,1)))
         codegen(sf("%s = cos", self:ref(2,2)))
         codegen(sf("%s =-sin", self:ref(2,3)))
         codegen(sf("%s = 0",   self:ref(3,1)))
         codegen(sf("%s = sin", self:ref(3,2)))
         codegen(sf("%s = cos", self:ref(3,3)))
         codegen "end"
      end
      return self
   end

   function ctx:mat3_rotate_y(angle)
      local self = ctx:mat(3,3):depends{angle}
      function self:emit_code(codegen)
         codegen "do"
         codegen(sf("local cos = math.cos(%s)", source_of(angle)))
         codegen(sf("local sin = math.sin(%s)", source_of(angle)))
         codegen(sf("%s = cos", self:ref(1,1)))
         codegen(sf("%s = 0",   self:ref(1,2)))
         codegen(sf("%s = sin", self:ref(1,3)))
         codegen(sf("%s = 0",   self:ref(2,1)))
         codegen(sf("%s = 1",   self:ref(2,2)))
         codegen(sf("%s = 0",   self:ref(2,3)))
         codegen(sf("%s =-sin", self:ref(3,1)))
         codegen(sf("%s = 0",   self:ref(3,2)))
         codegen(sf("%s = cos", self:ref(3,3)))
         codegen "end"
      end
      return self
   end

   function ctx:mat3_rotate_z(angle)
      local self = ctx:mat(3,3):depends{angle}
      function self:emit_code(codegen)
         codegen "do"
         codegen(sf("local cos = math.cos(%s)", source_of(angle)))
         codegen(sf("local sin = math.sin(%s)", source_of(angle)))
         codegen(sf("%s = cos", self:ref(1,1)))
         codegen(sf("%s =-sin", self:ref(1,2)))
         codegen(sf("%s = 0",   self:ref(1,3)))
         codegen(sf("%s = sin", self:ref(2,1)))
         codegen(sf("%s = cos", self:ref(2,2)))
         codegen(sf("%s = 0",   self:ref(2,3)))
         codegen(sf("%s = 0",   self:ref(3,1)))
         codegen(sf("%s = 0",   self:ref(3,2)))
         codegen(sf("%s = 1",   self:ref(3,3)))
         codegen "end"
      end
      return self
   end

   function ctx:mat3_rotate(angle, axis)
      -- axis must be a unit vector
      assert(is_vec(axis))
      assert(axis.size==3)
      local self = ctx:mat(3,3):depends{angle,axis}
      function self:emit_code(codegen)
         local function gen(x,y,n1,n2,n3,n3mul)
            codegen(sf("%s = %s",
                       self:ref(x,y),
                       sf("%s*(1-cos) + %s*%s",
                          sf("%s*%s", axis:ref(n1), axis:ref(n2)),
                          n3 == 0 and "1" or axis:ref(n3),
                          n3mul)))
         end
         codegen "do"
         codegen(sf("local cos = math.cos(%s)", source_of(angle)))
         codegen(sf("local sin = math.sin(%s)", source_of(angle)))
         gen(1,1,1,1,0,'cos')
         gen(1,2,1,2,3,'-sin')
         gen(1,3,1,3,2,'sin')
         gen(2,1,2,1,3,'sin')
         gen(2,2,2,2,0,'cos')
         gen(2,3,2,3,1,'-sin')
         gen(3,1,3,1,2,'-sin')
         gen(3,2,3,2,1,'sin')
         gen(3,3,3,3,0,'cos')
         codegen "end"
      end
      return self
   end

   function ctx:mat4_rotate(...)
      return ctx:mat3_rotate(...):extend(4)
   end

   function ctx:mat4_translate(v)
      assert(is_vec(v))
      assert(v.size==3)
      local self = ctx:mat_identity(4):depends{v}
      local super_emit_code = self.emit_code
      function self:emit_code(codegen)
         super_emit_code(self, codegen)
         codegen(sf("%s = %s", self:ref(1,4), v:ref(1)))
         codegen(sf("%s = %s", self:ref(2,4), v:ref(2)))
         codegen(sf("%s = %s", self:ref(3,4), v:ref(3)))
      end
      return self
   end

   function ctx:mat_scale(factor, axis)
      -- axis must be a unit vector
      assert(is_num(factor))
      assert(is_vec(axis))
      local self = ctx:mat(axis.size):depends{factor, axis}
      function self:emit_code(codegen)
         codegen "do"
         codegen(sf("local k1 = (%s)-1", source_of(factor)))
         for x=1,self.cols do
            for y=1,self.rows do
               codegen(sf("%s = %s",
                          self:ref(x,y),
                          sf("%d + k1*%s*%s",
                             x==y and 1 or 0,
                             axis:ref(x), axis:ref(y))))
            end
         end
         codegen "end"
      end
      return self
   end

   function ctx:mat4_perspective(fovy, aspect, znear, zfar)
      local elements = {}
      for x=1,4 do
         for y=1,4 do
            elements[(x-1)*4+y] = 0
         end
      end
      local zoom_y = 1 / math.tan(fovy/2)
      local zoom_x = zoom_y / aspect
      elements[0*4+1] = zoom_x
      elements[1*4+2] = zoom_y
      elements[2*4+3] = (zfar + znear) / (zfar - znear)
      elements[2*4+4] = (2 * znear * zfar) / (znear - zfar)
      elements[3*4+3] = 1
      return ctx:mat(4, 4, elements)
   end

   function ctx:assign(lhs, rhs)
      local self = ctx:stmt("assign"):depends{lhs, rhs}
      function self:emit_code(codegen)
         if is_vec(lhs) then
            assert(is_vec(rhs))
            assert(lhs.size==rhs.size)
            for i=1,lhs.size do
               codegen(sf("%s = %s", lhs:ref(i), rhs:ref(i)))
            end
         elseif is_num(lhs) then
            assert(is_num(rhs))
            codegen(sf("%s = %s", lhs:var(), source_of(rhs)))
         else
            ef("cannot assign to node of type %s", lhs.type)
         end
      end
      return self
   end

   function ctx:when(expr, stmt1, stmt2)
      local self = ctx:stmt("when"):depends{expr, stmt1, stmt2}
      function self:emit_code(codegen)
         codegen(sf("if %s then", source_of(expr)))
         stmt1:emit_code(codegen)
         if stmt2 then
            codegen("else")
            stmt2:emit_code(codegen)
         end
         codegen("end")
      end
      return self
   end

   function ctx:lognot(expr)
      local self = ctx:bool():depends{expr}
      function self:expr()
         return sf("not %s", source_of(expr))
      end
      return self
   end

   function ctx:logop(op, ...)
      local params = {...}
      local self = ctx:bool():depends(params)
      function self:expr()
         return sources_of(params, sf(" %s ", op))
      end
      return self
   end

   function ctx:logand(...)
      return ctx:logop("and", ...)
   end

   function ctx:lt(arg1, arg2)
      return ctx:logop("<", arg1, arg2)
   end

   function ctx:le(arg1, arg2)
      return ctx:logop("<=", arg1, arg2)
   end

   function ctx:gt(arg1, arg2)
      return ctx:logop(">", arg1, arg2)
   end

   function ctx:ge(arg1, arg2)
      return ctx:logop(">=", arg1, arg2)
   end

   local function once_per_node(fn)
      local nodes_seen = {}
      return function(node)
         if not nodes_seen[node] then
            fn(node)
            nodes_seen[node] = true
         end
      end
   end

   function ctx:compile(...)
      local roots = {...}

      -- mark all root values as output parameters
      for _,node in ipairs(roots) do
         if is_value(node) then
            node:output()
         end
      end

      -- collect nodes which have an input parameter
      local input_nodes = {}
      local add_input_node = once_per_node(function(node)
         if node.param_kind == "input" then
            table.insert(input_nodes, node)
         end
      end)
      for _,node in ipairs(roots) do
         node:invoke(add_input_node, true)
      end
      -- input parameters are passed in node construction order
      table.sort(input_nodes, function(a,b) return a.id < b.id end)
      local input_names = {}
      for _,node in ipairs(input_nodes) do
         table.insert(input_names, node:name())
      end

      local codegen_data = CodeGen()
      local codegen_code = CodeGen()
      local emit_node = once_per_node(function(node)
         if is_value(node) and node:requires_var() then
            node:emit_data(codegen_data)
         end
         if is_stmt(node) and #node.users > 0 then
            -- a statement with at least one user
            -- shall be emitted by its user(s)
            do end
         elseif is_value(node) and not node:requires_var() then
            -- a value node without a var does not need an initializer
            -- (its expr will be expanded inline)
            do end
         else
            node:emit_code(codegen_code)
         end
      end)
      for _,node in ipairs(roots) do
         node:invoke(emit_node, true)
      end

      local codegen = CodeGen()
      codegen("local ffi = require('ffi')")
      codegen(codegen_data:code())
      codegen(sf("return function (%s)", table.concat(input_names,',')))
      codegen(codegen_code:code())
      codegen(sf("return %s", sources_of(roots, ',')))
      codegen("end")

      local code = codegen:code()
      --print(code)
      return assert(loadstring(code))()
   end

   return ctx
end

return M
