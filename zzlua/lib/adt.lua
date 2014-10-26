local M = {}

local List_mt = {}

function List_mt:push(item)
   table.insert(self._items, item)
end

function List_mt:shift()
   return table.remove(self._items, 1)
end

function List_mt:size()
   return #self._items
end

function List_mt:empty()
   return #self._items == 0
end

function List_mt:clear()
   self._items = {}
end

function List_mt:__index(pos)
   if type(pos) == "number" then
      return self._items[pos+1]
   else
      return rawget(List_mt, pos)
   end
end

function List_mt:iterkeys()
   local index = 0
   local function next()
      if index >= self:size() then
         return nil
      else
         local rv = index
         index = index + 1
         return rv
      end
   end
   return next
end

function List_mt:itervalues()
   local index = 0
   local function next()
      if index >= self:size() then
         return nil
      else
         local rv = self[index]
         index = index + 1
         return rv
      end
   end
   return next
end

function List_mt:iteritems()
   local index = 0
   local function next()
      if index >= self:size() then
         return nil
      else
         local k,v = index, self[index]
         index = index + 1
         return k,v
      end
   end
   return next
end

function M.List()
   local self = {
      _items = {}
   }
   return setmetatable(self, List_mt)
end

local OrderedList_mt = {}

function OrderedList_mt:push(item)
   local i = 1
   while i <= #self._items and self.key_fn(item) > self.key_fn(self._items[i]) do
      i = i + 1
   end
   table.insert(self._items, i, item)
end

function OrderedList_mt:__index(pos)
   if type(pos) == "number" then
      return self._items[pos+1]
   else
      return rawget(OrderedList_mt, pos) or rawget(List_mt, pos)
   end
end

function M.OrderedList(key_fn)
   local self = {
      _items = {},
      key_fn = key_fn or function(x) return x end,
   }
   return setmetatable(self, OrderedList_mt)
end

return M
