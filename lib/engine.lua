local gl = require('gl')
local sdl = require('sdl2')
local bit = require('bit')
local sched = require('sched')
local time = require('time')

local M = {}

local function exact_wait(target)
   -- we wait 2 ms less than required
   sched.wait(target-0.002)
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
      -- if SDL_WINDOW_OPENGL is set in flags, sdl.CreateWindow() will
      -- also try to create a context for us. that will only succeed
      -- if the desired profile and version are supported
      w:DestroyWindow()
   end
   local is_supported = pcall(try_create_context)
   return is_supported
end

-- SDLApp

local SDLApp_mt = {}

function SDLApp_mt:init()
end

function SDLApp_mt:main()
end

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

      -- create window
      local w = sdl.CreateWindow(self.title,
                                 self.x, self.y, 
                                 self.w, self.h,
                                 self.flags)
      self.window = w

      if self.create_renderer then
         self.renderer = w:CreateRenderer()
      end

      -- user-provided app initialization
      self:init()

      -- show window
      w:ShowWindow()

      -- update width/height
      self.w, self.h = w:GetWindowSize()

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
      if self.renderer then
         self.renderer:DestroyRenderer()
         self.renderer = nil
      end
      w:DestroyWindow()
   end)
   sched()
end

function SDLApp_mt:done()
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
   opts.hidden = true -- always start hidden, show when everything is ready
   if opts.gl_profile or opts.gl_version or opts.create_renderer then
      opts.opengl = true
   end
   local self = {
      x = opts.x or -1, -- -1 means centered
      y = opts.y or -1,
      w = opts.w or 640,
      h = opts.h or 480,
      title = opts.title or "SDLApp",
      gl_profile = opts.gl_profile,
      gl_version = opts.gl_version,
      create_renderer = opts.create_renderer or false,
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
   local self = M.SDLApp(opts)
   self.gl_profile = opts.gl_profile or 'core'
   self.gl_version = opts.gl_version or '2.1'
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
   -- use OpenGL ES 2.0 if it's available
   sdl.Init()
   if is_gl_version_supported('es', '2.0') then
      opts.gl_profile = 'es'
      opts.gl_version = '2.0'
   end
   opts.create_renderer = true
   local self = M.SDLApp(opts)
   self.exact_frame_timing = opts.exact_frame_timing or false
   return setmetatable(self, DesktopApp_mt)
end

return M
