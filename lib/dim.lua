local sdl = require('sdl2')
local ffi = require('ffi')

ffi.cdef [[

typedef struct zz_dim_size {
  int w;
  int h;
} zz_dim_size;

]]

local M = {}

M.Point = sdl.Point
M.Rect = sdl.Rect

local Size_mt = {}

function Size_mt:__tostring()
   return sf("Size(%d,%d)", self.w, self.h)
end

M.Size = ffi.metatype("zz_dim_size", Size_mt)

return M
