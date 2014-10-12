local re = require("re")
local sf = string.format

local M = {}

local Parser_mt = {}

function Parser_mt:eof()
   return self.pos == self.len or re.match("\\s+$", self.source, self.pos, re.ANCHORED)
end

function Parser_mt:skip(regex)
   local m = re.match(regex, self.source, self.pos, re.ANCHORED)
   if m then
      self.pos = self.pos + #m[0]
   end
end

function Parser_mt:match(regex)
   self:skip("\\s*")
   self.m = re.match(regex, self.source, self.pos, re.ANCHORED)
   return self.m
end

function Parser_mt:text(index)
   if index then
      return self.m[index]
   else
      return self.m[0]
   end
end

function Parser_mt:eat(regex, what)
   local m = regex and self:match(regex) or self.m
   if not m then
      if what then
         error(sf("parse error: expected a %s matching %s at position %d: %s",
                  what, regex, self.pos, re.match(".+\n", self.source, self.pos)))
      else
         error(sf("parse error: expected a match for %s at position %d: %s",
                  regex, self.pos, re.match(".+\n", self.source, self.pos)))
      end
   else
      self.pos = self.pos + #m[0]
      return m.stringcount == 1 and m[0] or m
   end
end

Parser_mt.__index = Parser_mt

function M.Parser(source)
   local self = {
      source = source,
      len = #source,
      pos = 0,
   }
   return setmetatable(self, Parser_mt)
end

return M
