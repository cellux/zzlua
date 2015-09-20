local ffi = require('ffi')

ffi.cdef [[

typedef unsigned long XID;
typedef XID Window;
typedef XID Pixmap;
typedef struct _XDisplay Display;

int XDisplayWidth(Display*, int);
int XDisplayWidthMM(Display*, int);
int XDisplayHeight(Display*, int);
int XDisplayHeightMM(Display*, int);

]]

local xlib = ffi.load("X11")

local M = {}

return setmetatable(M, { __index = xlib })
