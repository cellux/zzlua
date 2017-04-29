local ffi = require('ffi')
local util = require('util')

ffi.cdef [[

int SSL_library_init(void);

void OPENSSL_add_all_algorithms_noconf(void);
void OPENSSL_add_all_algorithms_conf(void);

void OpenSSL_add_all_ciphers(void);
void OpenSSL_add_all_digests(void);

struct env_md_ctx_st;
struct env_md_st;
struct engine_st;

typedef struct env_md_ctx_st EVP_MD_CTX;
typedef struct env_md_st EVP_MD;
typedef struct engine_st ENGINE;

EVP_MD_CTX *EVP_MD_CTX_create(void);

int EVP_DigestInit_ex(EVP_MD_CTX *ctx, const EVP_MD *type, ENGINE *impl);
int EVP_DigestUpdate(EVP_MD_CTX *ctx, const void *d, size_t cnt);
int EVP_DigestFinal_ex(EVP_MD_CTX *ctx, unsigned char *md, unsigned int *s);

const EVP_MD *EVP_get_digestbyname(const char *name);

int EVP_MD_type(const EVP_MD *md);
int EVP_MD_pkey_type(const EVP_MD *md);
int EVP_MD_size(const EVP_MD *md);
int EVP_MD_block_size(const EVP_MD *md);

static const int EVP_MAX_MD_SIZE = 64; /* SHA512 */

void EVP_MD_CTX_destroy(EVP_MD_CTX *ctx);

struct zz_openssl_EVP_MD_CTX {
  EVP_MD_CTX *ctx;
};

]]

local ssl = ffi.load("ssl")

-- load all digests and ciphers
ssl.SSL_library_init()
ssl.OPENSSL_add_all_algorithms_noconf()

local M = {}

function M.Digest(digest_type)
   local ctx = ssl.EVP_MD_CTX_create()
   local md = ssl.EVP_get_digestbyname(digest_type)
   if md == nil then
      ef("Unknown digest type: %s", digest_type)
   end
   util.check_ok("EVP_DigestInit_ex", 1, ssl.EVP_DigestInit_ex(ctx, md, nil))
   local self = {}
   function self:update(buf, size)
      util.check_ok("EVP_DigestUpdate", 1, ssl.EVP_DigestUpdate(ctx, buf, size or #buf))
   end
   function self:final()
      local md_size = ssl.EVP_MD_size(md)
      local buf = ffi.new("unsigned char[?]", md_size)
      util.check_ok("EVP_DigestFinal_ex", 1, ssl.EVP_DigestFinal_ex(ctx, buf, nil))
      return ffi.string(buf, md_size)
   end
   return self
end

return setmetatable(M, { __index = ssl })
