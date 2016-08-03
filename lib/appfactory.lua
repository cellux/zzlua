local gl = require('gl')
local sdl = require('sdl2')
local bit = require('bit')
local sched = require('sched')
local util = require('util')

local M = {}

M.DEFAULT_REFRESH_RATE = 60

local function exact_wait_until(target)
   -- WARNING: use of this function considerably increases CPU usage
   sched.wait(target-sched.precision)
   while sched.time() < target do
      -- busy wait to fix timing irregularities
   end
end

local function resolve_gl_profile_mask(gl_profile_name)
   local gl_profile_masks = {
      core = sdl.SDL_GL_CONTEXT_PROFILE_CORE,
      compatibility = sdl.SDL_GL_CONTEXT_PROFILE_COMPATIBILITY,
      es = sdl.SDL_GL_CONTEXT_PROFILE_ES
   }
   local gl_profile_mask = gl_profile_masks[gl_profile_name]
   if not gl_profile_mask then
      ef("Invalid GL profile: %s", gl_profile_name)
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
   sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, resolve_gl_profile_mask(profile))
   local major, minor = parse_gl_version(version)
   sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, major)
   sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, minor)
   local function try_create_context()
      local w = sdl.CreateWindow('OpenGL version test', 0, 0, 16, 16,
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
   if opts.create_context and opts.create_renderer then
      ef("Create either a GL context or a renderer, but not both")
   end
   local self = {
      x = opts.x or -1, -- -1 means centered
      y = opts.y or -1,
      width = opts.width or sdl.DEFAULT_WINDOW_WIDTH,
      height = opts.height or sdl.DEFAULT_WINDOW_HEIGHT,
      title = opts.title or "SDLApp",
      gl_profile = opts.gl_profile,
      gl_version = opts.gl_version,
      create_context = opts.create_context,
      create_renderer = opts.create_renderer,
      create_ui = true,
      exact_frame_timing = opts.exact_frame_timing or false,
      frame_time = opts.frame_time,
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

function SDLApp:determine_fps()
   local mode = self.window:GetWindowDisplayMode()
   if mode.refresh_rate == 0 then
      pf("Warning: cannot determine screen refresh rate, using default (%d)", M.DEFAULT_REFRESH_RATE)
      return M.DEFAULT_REFRESH_RATE
   else
      return mode.refresh_rate
   end
end

function SDLApp:main()
   self.fps = self:determine_fps()
   if not self.frame_time then
      self.frame_time = 1/self.fps
   end
   local now = sched.now
   local prev_now
   local running = true
   while self.running do
      prev_now = now
      now = sched.now
      self:draw()
      if self.ctx then
         local gl_error = gl.GetError()
         if gl_error ~= gl.GL_NO_ERROR then
            ef("GL error: %x", gl_error)
         end
      end
      if self.ctx then
         self.window:GL_SwapWindow()
      else
         self.renderer:RenderPresent()
      end
      local delta = now - prev_now
      self:update(delta)
      if self.frame_time > 0 then
         local next_frame_start = now + self.frame_time
         if self.exact_frame_timing then
            exact_wait_until(next_frame_start)
         else
            sched.wait(next_frame_start)
         end
      else
         sched.yield()
      end
   end
end

function SDLApp:draw()
end

function SDLApp:update(delta)
end

function SDLApp:run()
   sched(function()
      if self.gl_profile then
         sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, resolve_gl_profile_mask(self.gl_profile))
      end

      if self.gl_version then
         local major, minor = parse_gl_version(self.gl_version)
         sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, major)
         sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, minor)
      end

      sdl.GL_SetAttribute(sdl.SDL_GL_DOUBLEBUFFER, 1)

      -- always start hidden, show when everything is ready
      local flags = bit.bor(self.flags, sdl.SDL_WINDOW_HIDDEN)

      -- create window
      local w = sdl.CreateWindow(self.title,
                                 self.x, self.y, 
                                 self.width, self.height,
                                 flags)
      self.window = w

      if self.create_context then
         assert(gl.GetError() == gl.GL_NO_ERROR)
         self.ctx = w:GL_CreateContext()
         assert(gl.GetError() == gl.GL_NO_ERROR)
         self.ctx:GL_MakeCurrent()
         assert(gl.GetError() == gl.GL_NO_ERROR)
      elseif self.create_renderer then
         self.renderer = w:CreateRenderer()
      end

      if self.ctx then
         -- this is what the OpenGL SDL renderer does if
         -- SDL_RENDERER_PRESENTVSYNC is specified
         sdl.SDL_GL_SetSwapInterval(1)
         assert(sdl.SDL_GL_GetSwapInterval()==1)
      end

      if self.create_ui then
         if self.ctx then
            if self.gl_profile == 'es' then
               self.ui = require('ui.gles2')(self.window)
            elseif self.gl_profile == 'core' then
               self.ui = require('ui.gl')(self.window)
            else
               ef("Cannot create UI object: gl_profile should be either 'es' or 'core'")
            end
         elseif self.renderer then
            self.ui = require('ui.sdl')(self.window, self.renderer)
         else
            ef("Cannot create UI object: requires either a GL context or a renderer")
         end
      end

      -- user-provided initialization
      self:init()

      -- show window
      w:ShowWindow()

      -- mapping the window may change its width/height
      self.width, self.height = w:GetWindowSize()
      if self.ctx then
         gl.Viewport(0, 0, self.width, self.height)
      end
      if self.ui then
         -- ui.layout() gets the current width/height of the window
         self.ui:layout()
      end

      self.running = true
      sched.on('sdl.keydown', function(evdata)
                  if evdata.key.keysym.sym == sdl.SDLK_ESCAPE then
                     self.running = false
                  end
      end)
      sched.on('sdl.quit', function() self.running = false end)

      self:main() -- shall exit when self.running becomes false

      -- user-provided cleanup
      self:done()

      if self.ui then
         self.ui:delete()
         self.ui = nil
      end
      if self.ctx then
         self.ctx:GL_DeleteContext()
         self.ctx = nil
      elseif self.renderer then
         self.renderer:DestroyRenderer()
         self.renderer = nil
      end
      if self.window then
         self.window:DestroyWindow()
         self.window = nil
      end

      -- stop all other threads and exit to the OS
      sched.quit()
   end)
   sched()
end

M.SDLApp = SDLApp

-- OpenGLApp

local OpenGLApp = util.Class(SDLApp)

function OpenGLApp:create(opts)
   opts = opts or {}
   opts.opengl = true
   opts.create_renderer = false
   opts.gl_profile = opts.gl_profile or 'core'
   opts.gl_version = opts.gl_version or '3.0'
   return SDLApp(opts)
end

M.OpenGLApp = OpenGLApp

-- DesktopApp

local DesktopApp = util.Class(SDLApp)

function DesktopApp:create(opts)
   opts = opts or {}
   opts.create_renderer = true
   -- let the renderer figure out the best way to accelerate rendering
   opts.opengl = false
   return SDLApp(opts)
end

M.DesktopApp = DesktopApp

return M
