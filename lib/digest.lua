local ssl = require('openssl')

local M = {}

local M_mt = {}

function M_mt:__index(digest_type)
   return function(data)
      if data then
         local md = ssl.Digest(digest_type)
         md:update(data)
         return md:final()
      else
         return ssl.Digest(digest_type)
      end
   end
end

return setmetatable(M, M_mt)
