local util = require('util')

local M = {}

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

function M.CompilerContext(opts)
   opts = opts or {}
   local numtype = opts.numtype or 'float'

   local ctx = {}

   local node_counter = util.Counter()

   local function is_node(x)
      return type(x)=="table" and x.type
   end

   local function is_node_type(x, t)
      return is_node(x) and x.type==t
   end

   local function is_num(x)
      return type(x)=="number" or is_node_type(x, "num")
   end

   local function is_vec(x)
      return is_node_type(x, "vec")
   end

   local function is_mat(x)
      return is_node_type(x, "mat")
   end

   function ctx:node(t)
      local self = {
         type = t,
         id = node_counter(),
         deps = {},
         assigned_name = nil,
         is_param = false,
      }
      function self:param(name)
         if name then
            self.assigned_name = name
         end
         self.is_param = true
         return self
      end
      function self:name()
         return self.assigned_name or sf('%s_%d', t, self.id)
      end
      function self:var()
         if self.is_param then
            return sf('_.%s', self:name())
         else
            return self:name()
         end
      end
      function self:depends(items)
         assert(type(items)=="table")
         self.deps = {}
         for _,x in ipairs(items) do
            if is_node(x) then
               table.insert(self.deps, x)
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
      function self:emit_decl_l(codegen)
         codegen(sf("local %s", self:name()))
      end
      function self:emit_decl_p(codegen)
         -- to be implemented downstream
      end
      function self:emit_code(codegen)
         -- to be implemented downstream
      end
      return self
   end

   local function source_of(x)
      return sf('%s', is_node(x) and x:var() or x)
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

   function ctx:fn(func_name, ...)
      local params = {...}
      local self = ctx:node("num"):depends(params)
      function self:emit_decl_p(codegen)
         codegen(sf("%s %s;", numtype, self:name()))
      end
      function self:emit_code(codegen)
         codegen(sf("%s = %s(%s)",
                    self:var(),
                    func_name,
                    sources_of(params, ',')))
      end
      return self
   end

   function ctx:binop(op, arg1, arg2)
      local self = ctx:node("num"):depends{arg1, arg2}
      function self:emit_decl_p(codegen)
         codegen(sf("%s %s;", numtype, self:name()))
      end
      function self:emit_code(codegen)
         codegen(sf("%s = (%s %s %s)",
                    self:var(),
                    source_of(arg1), op, source_of(arg2)))
      end
      return self
   end

   -- vector

   local vec_mt = {}

   function vec_mt:index(i)
      if self.is_param then
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

   function vec_mt.__add(lhs, rhs)
      assert(is_vec(lhs))
      assert(is_vec(rhs))
      assert(lhs.size == rhs.size)
      local self = ctx:vec(lhs.size):depends{lhs, rhs}
      function self:emit_code(codegen)
         for i=1,self.size do
            codegen(sf("%s = %s + %s",
                       self:ref(i),
                       lhs:ref(i),
                       rhs:ref(i)))
         end
      end
      return self
   end

   function vec_mt.__sub(lhs, rhs)
      return lhs + -rhs
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
            codegen(sf("local m = %s", source_of(rhs)))
            for i=1,self.size do
               codegen(sf("%s = %s * m", self:ref(i), lhs:ref(i)))
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
      return lhs * ctx:binop("/", 1, rhs)
   end

   function vec_mt.__len(v)
      local self = ctx:node("num"):depends{v}
      function self:emit_decl_p(codegen)
         codegen(sf("%s %s;", numtype, self:name()))
      end
      function self:emit_code(codegen)
         local terms = {}
         for i=1,v.size do
            table.insert(terms, sf("%s*%s", v:ref(i), v:ref(i)))
         end
         codegen(sf("%s = math.sqrt(%s)", self:var(), table.concat(terms,'+')))
      end
      return self
   end

   function vec_mt:mag()
      return #self
   end

   function vec_mt.normalize(v)
      return v * ctx:binop("/", 1, #v)
   end

   function vec_mt:project(v2)
      local dot = ctx:dot(self, v2)
      local v2_mag = #v2
      local sq = ctx:binop("*", v2_mag, v2_mag)
      return v2 * ctx:binop("/", dot, sq)
   end

   vec_mt.__index = vec_mt

   function ctx:vec(size, init)
      local elements = {}
      assert(type(size)=="number")
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
      local self = ctx:node("vec")
      self.size = size
      function self:emit_decl_l(codegen)
         codegen(sf("local %s = {%s}",
                    self:name(),
                    sources_of(elements, ',')))
      end
      function self:emit_decl_p(codegen)
         codegen(sf("%s %s[%d];", numtype, self:name(), self.size))
      end
      function self:emit_code(codegen)
         if self.is_param then
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
      local self = ctx:node("num"):depends{lhs, rhs}
      function self:emit_decl_p(codegen)
         codegen(sf("%s %s;", numtype, self:name()))
      end
      function self:emit_code(codegen)
         local terms = {}
         for i=1,lhs.size do
            table.insert(terms, sf("%s*%s", lhs:ref(i), rhs:ref(i)))
         end
         codegen(sf("%s = %s",
                    self:var(),
                    table.concat(terms,'+')))
      end
      return self
   end

   function ctx:cross(lhs, rhs)
      assert(is_vec(lhs))
      assert(is_vec(rhs))
      assert(lhs.size==rhs.size)
      assert(lhs.size==3)
      local self = ctx:vec(lhs.size):depends{lhs, rhs}
      function self:emit_code(codegen)
         codegen(sf("%s = %s*%s - %s*%s",
                    self:ref(1),
                    lhs:ref(2), rhs:ref(3),
                    lhs:ref(3), rhs:ref(2)))
         codegen(sf("%s = %s*%s - %s*%s",
                    self:ref(2),
                    lhs:ref(3), rhs:ref(1),
                    lhs:ref(1), rhs:ref(3)))
         codegen(sf("%s = %s*%s - %s*%s",
                    self:ref(3),
                    lhs:ref(1), rhs:ref(2),
                    lhs:ref(2), rhs:ref(1)))
      end
      return self
   end

   function ctx:distance(v1, v2)
      return #(v2-v1)
   end

   function ctx:angle(v1, v2)
      return ctx:fn("math.acos",
                    ctx:binop("/",
                              ctx:dot(v1,v2),
                              ctx:binop("*", #v1, #v2)))
   end

   -- matrix

   local mat_mt = {}

   function mat_mt:index(x, y)
      local i = (x - 1) * self.rows + y
      if self.is_param then
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
         local self = ctx:mat(lhs.rows, lhs.cols):depends{lhs, rhs}
         function self:emit_code(codegen)
            codegen("do")
            codegen(sf("local m = %s", source_of(rhs)))
            for x=1,self.cols do
               for y=1,self.rows do
                  codegen(sf("%s = %s * m",
                             self:ref(x,y),
                             lhs:ref(x,y)))
               end
            end
            codegen("end")
         end
         return self
      elseif is_mat(rhs) then
         assert(lhs.cols==rhs.rows)
         local self = ctx:mat(lhs.rows, rhs.cols):depends{lhs, rhs}
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

   function vec_mt.__div(lhs, rhs)
      assert(is_node(lhs) and lhs.type=="vec")
      return lhs * ctx:binop("/", 1, rhs)
   end

   function mat_mt.transpose(m)
      local self = ctx:mat(m.cols, m.rows):depends{m}
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

   mat_mt.__index = mat_mt

   function ctx:mat(rows, cols, init)
      local elements = {}
      assert(type(rows)=="number")
      cols = cols or rows
      assert(type(cols)=="number")
      local size = cols * rows
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
      local self = ctx:node("mat")
      self.rows = rows
      self.cols = cols
      self.size = size
      function self:emit_decl_l(codegen)
         codegen(sf("local %s = {%s}",
                    self:name(),
                    sources_of(elements, ',')))
      end
      function self:emit_decl_p(codegen)
         codegen(sf("%s %s[%d];", numtype, self:name(), size))
      end
      function self:emit_code(codegen)
         if self.is_param then
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

   function ctx:mat4_perspective(fovy, aspect, znear, zfar)
      local elements = {}
      for x=1,4 do
         for y=1,4 do
            elements[(x-1)*4+y] = 0
         end
      end
      local tan_half_fovy = math.tan(fovy/2)
      elements[0*4+1] = 1 / (aspect * tan_half_fovy)
      elements[1*4+2] = 1 / tan_half_fovy
      elements[2*4+3] = (zfar + znear) / (zfar - znear)
      elements[3*4+3] = -(2 * zfar * znear) / (zfar - znear)
      return ctx:mat(4, 4, elements)
   end

   function ctx:compile(...)
      local roots = {...}
      -- mark all roots as (output) parameters
      for _,node in ipairs(roots) do
         node:invoke(function(n) n:param() end, false)
      end
      local codegen = CodeGen()
      codegen "local ffi = require('ffi')"
      codegen "local mt = {}"
      local codegen_p = CodeGen() -- params
      local codegen_l = CodeGen() -- locals
      local emit_decl_invoked = {}
      local function emit_decl(node)
         if not emit_decl_invoked[node] then
            if node.is_param then
               node:emit_decl_p(codegen_p)
            else
               node:emit_decl_l(codegen_l)
            end
            emit_decl_invoked[node] = true
         end
      end
      for _,node in ipairs(roots) do
         node:invoke(emit_decl, true)
      end
      local struct_name = sf("zz_mathcomp_%d", next_struct_id())
      codegen(sf("ffi.cdef [[ struct %s {", struct_name))
      codegen(codegen_p:code())
      codegen "}; ]]"
      codegen "function mt.calculate(_)"
      codegen(codegen_l:code())
      local emit_code_invoked = {}
      local function emit_code(node)
         if not emit_code_invoked[node] then
            node:emit_code(codegen)
            emit_code_invoked[node] = true
         end
      end
      for _,node in ipairs(roots) do
         node:invoke(emit_code, true)
      end
      codegen "return _"
      codegen "end"
      codegen "function mt.outputs(_)"
      codegen(sf("return %s", sources_of(roots, ',')))
      codegen "end"
      codegen "mt.__index = mt"
      codegen(sf("return ffi.metatype('struct %s', mt)()", struct_name))
      local code = codegen:code()
      --print(code)
      return assert(loadstring(code))()
   end

   return ctx
end

return setmetatable(M, { __call = M.CompilerContext })
