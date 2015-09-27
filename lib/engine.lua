local gl = require('gl')
local sdl = require('sdl2')
local bit = require('bit')
local sched = require('sched')
local time = require('time')

local M = {}

local function exact_wait(target)
   sched.wait(target-sched.precision)
   while time.time() < target do
      -- busy wait to fix timing irregularities
   end
end

local function get_gl_profile_mask(gl_profile)
   local gl_profile_masks = {
      core = sdl.SDL_GL_CONTEXT_PROFILE_CORE,
      compatibility = sdl.SDL_GL_CONTEXT_PROFILE_COMPATIBILITY,
      es = sdl.SDL_GL_CONTEXT_PROFILE_ES
   }
   local gl_profile_mask = gl_profile_masks[gl_profile]
   if not gl_profile_mask then
      ef("Invalid GL profile: %s", gl_profile)
   end
   return gl_profile_mask
end

local function parse_gl_version(gl_version)
   local major, minor = string.match(gl_version, "^(%d+)%.(%d+)$")
   if not major then
      ef("Invalid GL version string: %s", gl_version)
   end
   return tonumber(major), tonumber(minor)
end

local function is_gl_version_supported(profile, version)
   sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, get_gl_profile_mask(profile))
   local major, minor = parse_gl_version(version)
   sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, major)
   sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, minor)
   local function try_create_context()
      local w = sdl.CreateWindow('opengl version test',0,0,16,16,
                                 bit.bor(sdl.SDL_WINDOW_OPENGL,
                                         sdl.SDL_WINDOW_HIDDEN))
      local ctx = w:GL_CreateContext()
      ctx:GL_DeleteContext()
      w:DestroyWindow()
   end
   local is_supported = pcall(try_create_context)
   return is_supported
end

-- AppBase

local AppBase_mt = {}

function AppBase_mt:init() end
function AppBase_mt:main() end
function AppBase_mt:done() end

function AppBase_mt:run() end

AppBase_mt.__index = AppBase_mt

-- SDLApp

local SDLApp_mt = setmetatable({}, AppBase_mt)

function SDLApp_mt:run()
   sched(function()
      if self.gl_profile then
         sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, get_gl_profile_mask(self.gl_profile))
      end

      if self.gl_version then
         local major, minor = parse_gl_version(self.gl_version)
         sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, major)
         sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, minor)
      end

      -- always start hidden, show when everything is ready
      local flags = bit.bor(self.flags, sdl.SDL_WINDOW_HIDDEN)

      -- create window
      local w = sdl.CreateWindow(self.title,
                                 self.x, self.y, 
                                 self.width, self.height,
                                 flags)
      self.window = w

      if self.create_renderer then
         self.renderer = w:CreateRenderer()
      end

      if self.create_context then
         assert(gl.GetError() == gl.GL_NO_ERROR)
         self.ctx = w:GL_CreateContext()
         assert(gl.GetError() == gl.GL_NO_ERROR)
         self.ctx:GL_MakeCurrent()
         assert(gl.GetError() == gl.GL_NO_ERROR)
      end

      -- user-provided app initialization
      self:init()

      -- show window
      w:ShowWindow()

      -- update width/height
      self.width, self.height = w:GetWindowSize()

      -- register quit handlers
      sched.on('sdl.keydown', function(evdata)
                  if evdata.key.keysym.sym == sdl.SDLK_ESCAPE then
                     sched.quit()
                  end
      end)
      sched.on('sdl.quit', sched.quit)

      -- run app
      self:main()

      -- cleanup
      self:done()
      if self.ctx then
         self.ctx:GL_DeleteContext()
         self.ctx = nil
      end
      if self.renderer then
         self.renderer:DestroyRenderer()
         self.renderer = nil
      end
      w:DestroyWindow()
   end)
   sched()
end

function SDLApp_mt:determine_fps()
   local mode = self.window:GetWindowDisplayMode()
   if mode.refresh_rate == 0 then
      pf("Warning: cannot determine screen refresh rate, using default (60)")
      return 60
   else
      return mode.refresh_rate
   end
end

SDLApp_mt.__index = SDLApp_mt

local sdl_window_flags = {
   fullscreen = sdl.SDL_WINDOW_FULLSCREEN,
   opengl = sdl.SDL_WINDOW_OPENGL,
   shown = sdl.SDL_WINDOW_SHOWN,
   hidden = sdl.SDL_WINDOW_HIDDEN,
   borderless = sdl.SDL_WINDOW_BORDERLESS,
   resizable = sdl.SDL_WINDOW_RESIZABLE,
   minimized = sdl.SDL_WINDOW_MINIMIZED,
   maximized = sdl.SDL_WINDOW_MAXIMIZED,
   input_grabbed = sdl.SDL_WINDOW_INPUT_GRABBED,
   input_focus = sdl.SDL_WINDOW_INPUT_FOCUS,
   mouse_focus = sdl.SDL_WINDOW_MOUSE_FOCUS,
   fullscreen_desktop = sdl.SDL_WINDOW_FULLSCREEN_DESKTOP,
   foreign = sdl.SDL_WINDOW_FOREIGN,
   allow_highdpi = sdl.SDL_WINDOW_ALLOW_HIGHDPI,
}

function M.SDLApp(opts)
   opts = opts or {}
   if opts.gl_profile or opts.gl_version then
      opts.opengl = true
   end
   if opts.create_context == nil then
      opts.create_context = opts.opengl and true or false
   end
   if opts.create_renderer == nil then
      opts.create_renderer = false
   end
   local self = {
      x = opts.x or -1, -- -1 means centered
      y = opts.y or -1,
      width = opts.width or 640,
      height = opts.height or 480,
      title = opts.title or "SDLApp",
      gl_profile = opts.gl_profile,
      gl_version = opts.gl_version,
      create_context = opts.create_context,
      create_renderer = opts.create_renderer,
   }
   local flags = 0
   for k,v in pairs(sdl_window_flags) do
      if opts[k] then
         flags = bit.bor(flags, v)
      end
   end
   self.flags = flags
   return setmetatable(self, SDLApp_mt)
end

-- OpenGLApp

local OpenGLApp_mt = setmetatable({}, SDLApp_mt)

function OpenGLApp_mt:main()
   self.fps = self:determine_fps()
   while true do
      local now = sched.now
      self:draw()
      local gl_error = gl.GetError()
      if gl_error ~= gl.GL_NO_ERROR then
         ef("GL error: %d", gl_error)
      end
      self.window:GL_SwapWindow()
      if self.exact_frame_timing then
         exact_wait(now+1/self.fps)
      else
         sched.wait(now+1/self.fps)
      end
   end
end

function OpenGLApp_mt:draw()
end

OpenGLApp_mt.__index = OpenGLApp_mt

function M.OpenGLApp(opts)
   opts = opts or {}
   opts.opengl = true
   opts.gl_profile = opts.gl_profile or 'core'
   opts.gl_version = opts.gl_version or '2.1'
   local self = M.SDLApp(opts)
   self.exact_frame_timing = opts.exact_frame_timing or false
   return setmetatable(self, OpenGLApp_mt)
end

-- DesktopApp

local DesktopApp_mt = setmetatable({}, SDLApp_mt)

function DesktopApp_mt:main()
   self.fps = self:determine_fps()
   while true do
      local now = sched.now
      self:draw()
      self.renderer:RenderPresent()
      if self.exact_frame_timing then
         exact_wait(now+1/self.fps)
      else
         sched.wait(now+1/self.fps)
      end
   end
end

function DesktopApp_mt:draw()
end

DesktopApp_mt.__index = DesktopApp_mt

function M.DesktopApp(opts)
   opts = opts or {}
   opts.create_renderer = true
   -- let the renderer figure out the best way to accelerate rendering
   opts.opengl = false
   opts.create_context = false
   local self = M.SDLApp(opts)
   self.exact_frame_timing = opts.exact_frame_timing or false
   return setmetatable(self, DesktopApp_mt)
end

return M
