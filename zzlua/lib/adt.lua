local M = {}

local List = {}

function List:push(item)
   table.insert(self.items, item)
end

function List:shift()
   return table.remove(self.items, 1)
end

function List:size()
   return #self.items
end

function List:empty()
   return #self.items == 0
end

function List:__index(pos)
   if type(pos) == "number" then
      return self.items[pos+1]
   else
      return List[pos]
   end
end

function M.List()
   local self = {
      items = {}
   }
   return setmetatable(self, List)
end

local OrderedList = {}

function OrderedList:push(item)
   local i = 1
   while i <= #self.items and self.key_fn(item) > self.key_fn(self.items[i]) do
      i = i + 1
   end
   table.insert(self.items, i, item)
end

function OrderedList:__index(pos)
   if type(pos) == "number" then
      return self.items[pos+1]
   else
      return OrderedList[pos]
   end
end

OrderedList.shift = List.shift
OrderedList.size = List.size
OrderedList.empty = List.empty

function M.OrderedList(key_fn)
   local self = {
      items = {},
      key_fn = key_fn or function(x) return x end,
   }
   return setmetatable(self, OrderedList)
end

return M
