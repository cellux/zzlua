local gl = require('gl')
local sdl = require('sdl2')
local bit = require('bit')
local sched = require('sched')
local time = require('time')
local util = require('util')

local M = {}

M.DEFAULT_REFRESH_RATE = 60

local function exact_wait(target)
   -- WARNING: use of this function considerably increases CPU usage
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
      local w = sdl.CreateWindow('opengl version test', 0, 0, 16, 16,
                                 bit.bor(sdl.SDL_WINDOW_OPENGL,
                                         sdl.SDL_WINDOW_HIDDEN))
      local ctx = w:GL_CreateContext()
      ctx:GL_DeleteContext()
      w:DestroyWindow()
   end
   local can_create_gl_context = pcall(try_create_context)
   return can_create_gl_context
end

-- AppBase

local AppBase = util.Class()

function AppBase:init() end
function AppBase:main() end
function AppBase:done() end

function AppBase:run() end

M.AppBase = AppBase

-- SDLApp

local SDLApp = util.Class(AppBase)

function SDLApp:run()
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

      if self.create_ui then
         if self.create_context then
            if self.gl_profile == 'es' then
               self.ui = require('ui.gles2')(self.window)
            elseif self.gl_profile == 'core' then
               self.ui = require('ui.gl')(self.window)
            else
               ef("Cannot create UI object: gl_profile should be set to either 'es' or 'core'")
            end
         elseif self.create_renderer then
            self.ui = require('ui.sdl')(self.window, self.renderer)
         else
            ef("Cannot create UI object: either create_context or create_renderer must be set")
         end
      end

      -- user-provided app initialization
      self:init()

      -- show window
      w:ShowWindow()

      -- update width/height
      self.width, self.height = w:GetWindowSize()
      self.ui.rect.w, self.ui.rect.h = self.width, self.height
      self.ui:layout()

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
      if self.ui then
         self.ui:delete()
         self.ui = nil
      end
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

function SDLApp:determine_fps()
   local mode = self.window:GetWindowDisplayMode()
   if mode.refresh_rate == 0 then
      pf("Warning: cannot determine screen refresh rate, using default (%d)", M.DEFAULT_REFRESH_RATE)
      return M.DEFAULT_REFRESH_RATE
   else
      return mode.refresh_rate
   end
end

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

function SDLApp:create(opts)
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
      create_ui = true,
   }
   local flags = 0
   for k,v in pairs(sdl_window_flags) do
      if opts[k] then
         flags = bit.bor(flags, v)
      end
   end
   self.flags = flags
   return self
end

M.SDLApp = SDLApp

-- OpenGLApp

local OpenGLApp = util.Class(SDLApp)

function OpenGLApp:main()
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

function OpenGLApp:draw()
end

function OpenGLApp:create(opts)
   opts = opts or {}
   opts.opengl = true
   opts.gl_profile = opts.gl_profile or 'core'
   opts.gl_version = opts.gl_version or '2.1'
   local self = SDLApp(opts)
   self.exact_frame_timing = opts.exact_frame_timing or false
   return self
end

M.OpenGLApp = OpenGLApp

-- DesktopApp

local DesktopApp = util.Class(SDLApp)

function DesktopApp:main()
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

function DesktopApp:draw()
end

function DesktopApp:create(opts)
   opts = opts or {}
   opts.create_renderer = true
   -- let the renderer figure out the best way to accelerate rendering
   opts.opengl = false
   opts.create_context = false
   local self = SDLApp(opts)
   self.exact_frame_timing = opts.exact_frame_timing or false
   return self
end

M.DesktopApp = DesktopApp

return M
