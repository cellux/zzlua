local ffi = require('ffi')
local util = require('util')
local xlib = require('xlib')

ffi.cdef [[

typedef signed   char          khronos_int8_t;
typedef unsigned char          khronos_uint8_t;
typedef signed   short int     khronos_int16_t;
typedef unsigned short int     khronos_uint16_t;
typedef int32_t                khronos_int32_t;
typedef uint32_t               khronos_uint32_t;
typedef int64_t                khronos_int64_t;
typedef uint64_t               khronos_uint64_t;
typedef float                  khronos_float_t;

typedef unsigned int EGLenum;
typedef khronos_int32_t EGLint;
typedef unsigned int EGLBoolean;

enum {
  EGL_FALSE = 0,
  EGL_TRUE  = 1
};

typedef void *EGLConfig;
typedef void *EGLContext;
typedef void *EGLDisplay;
typedef void *EGLSurface;
typedef void *EGLClientBuffer;

typedef Display *EGLNativeDisplayType;
typedef Pixmap   EGLNativePixmapType;
typedef Window   EGLNativeWindowType;

/* Errors / GetError return values */

enum {
  EGL_SUCCESS             = 0x3000,
  EGL_NOT_INITIALIZED     = 0x3001,
  EGL_BAD_ACCESS          = 0x3002,
  EGL_BAD_ALLOC           = 0x3003,
  EGL_BAD_ATTRIBUTE       = 0x3004,
  EGL_BAD_CONFIG          = 0x3005,
  EGL_BAD_CONTEXT         = 0x3006,
  EGL_BAD_CURRENT_SURFACE	= 0x3007,
  EGL_BAD_DISPLAY         = 0x3008,
  EGL_BAD_MATCH           = 0x3009,
  EGL_BAD_NATIVE_PIXMAP		= 0x300A,
  EGL_BAD_NATIVE_WINDOW		= 0x300B,
  EGL_BAD_PARAMETER       = 0x300C,
  EGL_BAD_SURFACE         = 0x300D,
  EGL_CONTEXT_LOST        = 0x300E
};

/* Config attributes */

enum {
  EGL_BUFFER_SIZE             = 0x3020,
  EGL_ALPHA_SIZE              = 0x3021,
  EGL_BLUE_SIZE               = 0x3022,
  EGL_GREEN_SIZE              = 0x3023,
  EGL_RED_SIZE                = 0x3024,
  EGL_DEPTH_SIZE              = 0x3025,
  EGL_STENCIL_SIZE            = 0x3026,
  EGL_CONFIG_CAVEAT           = 0x3027,
  EGL_CONFIG_ID               = 0x3028,
  EGL_LEVEL                   = 0x3029,
  EGL_MAX_PBUFFER_HEIGHT      = 0x302A,
  EGL_MAX_PBUFFER_PIXELS      = 0x302B,
  EGL_MAX_PBUFFER_WIDTH       = 0x302C,
  EGL_NATIVE_RENDERABLE       = 0x302D,
  EGL_NATIVE_VISUAL_ID        = 0x302E,
  EGL_NATIVE_VISUAL_TYPE      = 0x302F,
  EGL_SAMPLES                 = 0x3031,
  EGL_SAMPLE_BUFFERS          = 0x3032,
  EGL_SURFACE_TYPE            = 0x3033,
  EGL_TRANSPARENT_TYPE        = 0x3034,
  EGL_TRANSPARENT_BLUE_VALUE	= 0x3035,
  EGL_TRANSPARENT_GREEN_VALUE	= 0x3036,
  EGL_TRANSPARENT_RED_VALUE   = 0x3037,
  EGL_NONE                    = 0x3038,
  EGL_BIND_TO_TEXTURE_RGB     = 0x3039,
  EGL_BIND_TO_TEXTURE_RGBA    = 0x303A,
  EGL_MIN_SWAP_INTERVAL       = 0x303B,
  EGL_MAX_SWAP_INTERVAL       = 0x303C,
  EGL_LUMINANCE_SIZE          = 0x303D,
  EGL_ALPHA_MASK_SIZE         = 0x303E,
  EGL_COLOR_BUFFER_TYPE       = 0x303F,
  EGL_RENDERABLE_TYPE         = 0x3040,
  EGL_MATCH_NATIVE_PIXMAP     = 0x3041,
  EGL_CONFORMANT              = 0x3042
};

/* Config attribute values */

enum {
  EGL_SLOW_CONFIG           = 0x3050,
  EGL_NON_CONFORMANT_CONFIG	= 0x3051,
  EGL_TRANSPARENT_RGB       = 0x3052,
  EGL_RGB_BUFFER            = 0x308E,
  EGL_LUMINANCE_BUFFER      = 0x308F,
};

/* More config attribute values, for EGL_TEXTURE_FORMAT */

enum {
  EGL_NO_TEXTURE	 = 0x305C,
  EGL_TEXTURE_RGB	 = 0x305D,
  EGL_TEXTURE_RGBA = 0x305E,
  EGL_TEXTURE_2D	 = 0x305F
};

/* Config attribute mask bits */

/* EGL_SURFACE_TYPE mask bits */

enum {
  EGL_PBUFFER_BIT                 = 0x0001,
  EGL_PIXMAP_BIT                  = 0x0002,
  EGL_WINDOW_BIT                  = 0x0004,
  EGL_VG_COLORSPACE_LINEAR_BIT    = 0x0020,
  EGL_VG_ALPHA_FORMAT_PRE_BIT     = 0x0040,
  EGL_MULTISAMPLE_RESOLVE_BOX_BIT = 0x0200,
  EGL_SWAP_BEHAVIOR_PRESERVED_BIT = 0x0400
};

/* EGL_RENDERABLE_TYPE mask bits */

enum {
  EGL_OPENGL_ES_BIT	 = 0x0001,
  EGL_OPENVG_BIT		 = 0x0002,
  EGL_OPENGL_ES2_BIT = 0x0004,
  EGL_OPENGL_BIT		 = 0x0008
};

/* QuerySurface / SurfaceAttrib / CreatePbufferSurface targets */

enum {
  EGL_HEIGHT                = 0x3056,
  EGL_WIDTH                 = 0x3057,
  EGL_LARGEST_PBUFFER       = 0x3058,
  EGL_TEXTURE_FORMAT        = 0x3080,
  EGL_TEXTURE_TARGET        = 0x3081,
  EGL_MIPMAP_TEXTURE        = 0x3082,
  EGL_MIPMAP_LEVEL          = 0x3083,
  EGL_RENDER_BUFFER         = 0x3086,
  EGL_VG_COLORSPACE         = 0x3087,
  EGL_VG_ALPHA_FORMAT       = 0x3088,
  EGL_HORIZONTAL_RESOLUTION	= 0x3090,
  EGL_VERTICAL_RESOLUTION		= 0x3091,
  EGL_PIXEL_ASPECT_RATIO		= 0x3092,
  EGL_SWAP_BEHAVIOR         = 0x3093,
  EGL_MULTISAMPLE_RESOLVE		= 0x3099
};

/* EGL_RENDER_BUFFER values
   BindTexImage / ReleaseTexImage buffer targets */

enum {
  EGL_BACK_BUFFER			= 0x3084,
  EGL_SINGLE_BUFFER		= 0x3085
};

/* Back buffer swap behaviors */

enum {
  EGL_BUFFER_PRESERVED = 0x3094,
  EGL_BUFFER_DESTROYED = 0x3095
};

/* CreateContext attributes */

enum {
  EGL_CONTEXT_CLIENT_VERSION = 0x3098
};

/* BindAPI/QueryAPI targets */

enum {
  EGL_OPENGL_ES_API	= 0x30A0,
  EGL_OPENVG_API		= 0x30A1,
  EGL_OPENGL_API		= 0x30A2
};

EGLint eglGetError(void);

EGLDisplay eglGetDisplay(EGLNativeDisplayType display_id);
EGLBoolean eglInitialize(EGLDisplay dpy, EGLint *major, EGLint *minor);
EGLBoolean eglTerminate(EGLDisplay dpy);

EGLBoolean eglChooseConfig(EGLDisplay dpy, const EGLint *attrib_list,
			                     EGLConfig *configs, EGLint config_size,
			                     EGLint *num_config);
EGLBoolean eglGetConfigAttrib(EGLDisplay dpy, EGLConfig config,
			                        EGLint attribute, EGLint *value);

EGLSurface eglCreateWindowSurface(EGLDisplay dpy, EGLConfig config,
				                          EGLNativeWindowType win,
				                          const EGLint *attrib_list);
EGLBoolean eglDestroySurface(EGLDisplay dpy, EGLSurface surface);
EGLBoolean eglQuerySurface(EGLDisplay dpy, EGLSurface surface,
			                     EGLint attribute, EGLint *value);

EGLBoolean eglBindAPI(EGLenum api);
EGLenum eglQueryAPI(void);

EGLBoolean eglSwapInterval(EGLDisplay dpy, EGLint interval);

EGLContext eglCreateContext(EGLDisplay dpy, EGLConfig config,
			                      EGLContext share_context,
			                      const EGLint *attrib_list);
EGLBoolean eglDestroyContext(EGLDisplay dpy, EGLContext ctx);
EGLBoolean eglMakeCurrent(EGLDisplay dpy, EGLSurface draw,
			                    EGLSurface read, EGLContext ctx);

EGLBoolean eglWaitClient(void);
EGLBoolean eglSwapBuffers(EGLDisplay dpy, EGLSurface surface);

]]

local egl = ffi.load("EGL")

local M = {}

M.GetError = egl.eglGetError

local Display_mt = {}

function Display_mt:Initialize()
   local major = ffi.new("EGLint[1]")
   local minor = ffi.new("EGLint[1]")
   util.check_ok("eglInitialize", egl.EGL_TRUE,
                 egl.eglInitialize(self.dpy, major, minor))
   return major[0], minor[0]
end

function M.attrib_list(attribs)
   local n_attribs = 0
   for k,v in pairs(attribs) do
      n_attribs = n_attribs + 1
   end
   local attrib_list = ffi.new("EGLint[?]", n_attribs*2+1)
   local i=0
   for k,v in pairs(attribs) do
      if type(k) == "string" then
         k = k:upper()
         if k:sub(1,4) ~= "EGL_" then
            k = "EGL_" .. k
         end
         k = egl[k]
      end
      attrib_list[i] = k
      attrib_list[i+1] = v
      i = i + 2
   end
   attrib_list[i] = egl.EGL_NONE
   return attrib_list
end

function Display_mt:ChooseConfig(attribs)
   local attrib_list = M.attrib_list(attribs)
   local configs = ffi.new("EGLConfig[1]")
   local config_size = 1
   local num_config = ffi.new("EGLint[1]")
   util.check_ok("eglChooseConfig", egl.EGL_TRUE,
                 egl.eglChooseConfig(self.dpy, attrib_list,
                                     configs, config_size,
                                     num_config))
   return num_config[0] == 1 and configs[0] or nil
end

function Display_mt:GetConfigAttrib(config, attribute)
   local value = ffi.new("EGLint[1]")
   util.check_ok("eglGetConfigAttrib", egl.EGL_TRUE,
                 egl.eglGetConfigAttrib(self.dpy, config,
                                        attribute, value))
   return value[0]
end

local Surface_mt = {}

function Surface_mt:QuerySurface(attribute)
   local value = ffi.new("EGLint[1]")
   util.check_ok("eglQuerySurface", egl.EGL_TRUE,
                 egl.eglQuerySurface(self.dpy, self.surface,
                                     attribute, value))
   return value[0]
end

function Surface_mt:SwapBuffers()
   util.check_ok("eglSwapBuffers", egl.EGL_TRUE,
                 egl.eglSwapBuffers(self.dpy, self.surface))
end

function Surface_mt:DestroySurface()
   if self.surface then
      util.check_ok("eglDestroySurface", egl.EGL_TRUE,
                    egl.eglDestroySurface(self.dpy, self.surface))
      self.surface = nil
   end
end

Surface_mt.__index = Surface_mt
Surface_mt.__gc = Surface_mt.DestroySurface

function Display_mt:CreateWindowSurface(config, win, attrib_list)
   local surface = util.check_bad("eglCreateWindowSurface", nil,
                                  egl.eglCreateWindowSurface(
                                     self.dpy, config,
                                     ffi.cast("EGLNativeWindowType", win),
                                     attrib_list))
   local self = { dpy = self.dpy, surface = surface }
   return setmetatable(self, Surface_mt)
end

local Context_mt = {}

function Context_mt:MakeCurrent(draw, read)
   util.check_ok("eglMakeCurrent", egl.EGL_TRUE,
                 egl.eglMakeCurrent(self.dpy,
                                    draw.surface,
                                    read.surface,
                                    self.ctx))
end

function Context_mt:DestroyContext()
   util.check_ok("eglDestroyContext", egl.EGL_TRUE,
                 egl.eglDestroyContext(self.dpy, self.ctx))
end

Context_mt.__index = Context_mt
Context_mt.__gc = Context_mt.DestroyContext

function Display_mt:CreateContext(config, share_context, attrib_list)
   local ctx = util.check_bad("eglCreateContext", nil,
                              egl.eglCreateContext(self.dpy,
                                                   config,
                                                   share_context,
                                                   attrib_list))
   local self = { dpy = self.dpy, ctx = ctx }
   return setmetatable(self, Context_mt)
end

function Display_mt:Terminate()
   util.check_ok("eglTerminate", egl.EGL_TRUE,
                 egl.eglTerminate(self.dpy))
end

Display_mt.__index = Display_mt
Display_mt.__gc = Display_mt.Terminate

function M.GetDisplay(display_id)
   display_id = display_id or 0 -- 0: EGL_DEFAULT_DISPLAY
   local dpy = util.check_bad("eglGetDisplay", nil, egl.eglGetDisplay(ffi.cast("EGLNativeDisplayType", display_id)))
   local self = { dpy = dpy }
   return setmetatable(self, Display_mt)
end

function M.BindAPI(api)
   util.check_ok("eglBindAPI", egl.EGL_TRUE,
                 egl.eglBindAPI(api))
end

M.QueryAPI = egl.eglQueryAPI

function M.WaitClient()
   util.check_ok("eglWaitClient", egl.EGL_TRUE, egl.eglWaitClient())
end

return setmetatable(M, { __index = egl })
