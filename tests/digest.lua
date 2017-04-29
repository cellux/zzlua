local digest = require('digest')
local assert = require('assert')
local file = require('file')

local function fibonacci()
   local queue = {1,1}
   local function next()
      local rv = queue[1]
      queue[1] = queue[2]
      queue[2] = rv + queue[1]
      return rv
   end
   return next
end

local function hexstr(bytes)
   local pieces = {}
   for i=1,#bytes do
      table.insert(pieces, sf("%02x", bytes:byte(i)))
   end
   return table.concat(pieces)
end

local function test_digest(data, digest_fn, digest_hex)
   -- process the whole string at once
   assert.equals(hexstr(digest_fn(data)), digest_hex)
   -- process data in chunks
   local digest = digest_fn()
   for n in fibonacci() do
      local chunk = data:sub(1,n)
      digest:update(chunk)
      data = data:sub(n+1)
      if #data == 0 then
         break
      end
   end
   assert.equals(hexstr(digest:final()), digest_hex)
end

local data = file.read('testdata/arborescence.jpg')

test_digest(data, digest.md4, '97d7daac924ff41af3e37b14373ac179')
test_digest(data, digest.md5, '58823f6d5e1d154d37d9aa2dbaf27371')
test_digest(data, digest.sha1, '77dd6183ed6e8b0f829ae70844f9de74b5151d46')
test_digest(data, digest.sha224, '828f4268bdf4ae05d1ca32d0618840d29bec8309627b595f702c07ce')
test_digest(data, digest.sha256, 'fb0069a988163cead062b2b1b5dfca23a5d0e0a8abace9cbaf1007a0dc4931ae')
test_digest(data, digest.sha384, 'aa86c8de290c6c635da4bf6cff3d9e162d12070db9dda0660c20ee36b5759a2ee24d0bb01a89f746989fad971cb0d782')
test_digest(data, digest.sha512, 'a9ecfab822675ac5b0cf90dbe52897c9f0cd515f61ee725d967c0334c38f4abf6111f1d616e515e785306ab19846e168d4a814eb32b247a91534fec3ed20c32e')
test_digest(data, digest.mdc2, '13d5d1eb5ec6fd5de026113b45975a92')
test_digest(data, digest.ripemd160, 'b4054d90852eaa7696c55f7bfcd2e3eff284c2bc')
test_digest(data, digest.dss1, '77dd6183ed6e8b0f829ae70844f9de74b5151d46')
