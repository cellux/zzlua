local gl = require('gl')
local sdl = require('sdl2')
local bit = require('bit')
local sched = require('sched')

local M = {}

local OpenGLApp_mt = {}

function OpenGLApp_mt:init()
end

function OpenGLApp_mt:run()
   sched(function()
      -- set desired OpenGL profile
      local gl_profile_masks = {
         core = sdl.SDL_GL_CONTEXT_PROFILE_CORE,
         compatibility = sdl.SDL_GL_CONTEXT_PROFILE_COMPATIBILITY,
         es = sdl.SDL_GL_CONTEXT_PROFILE_ES
      }
      local gl_profile_mask = gl_profile_masks[self.gl_profile]
      if not gl_profile_mask then
         ef("Invalid value for gl_profile: %s", self.gl_profile)
      end
      sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, gl_profile_mask)

      -- set desired OpenGL version
      local major, minor = string.match(self.gl_version, "^(%d+)%.(%d+)$")
      if not major then
         ef("Invalid value for gl_version: %s", self.gl_version)
      end
      sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, tonumber(major))
      sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, tonumber(minor))

      -- create window
      local w = sdl.CreateWindow(self.title,
                                 self.x, self.y, 
                                 self.w, self.h,
                                 self.flags)

      -- user-provided app initialization
      self:init()

      -- show window
      w:show()

      -- register quit handlers
      sched.on('sdl.keydown', function(evdata)
                  if evdata.key.keysym.sym == sdl.SDLK_ESCAPE then
                     sched.quit()
                  end
      end)
      sched.on('sdl.quit', sched.quit)

      -- schedule the game loop
      sched(function()
            -- game loop
            while true do
               now = sched.now
               self:draw()
               local gl_error = gl.GetError()
               if gl_error ~= gl.GL_NO_ERROR then
                  ef("GL error: %d", gl_error)
               end
               w:swap()
               sched.wait(now+1/self.fps)
            end
      end)
      sched.wait('quit')

      -- cleanup
      self:done()
      w:destroy()
   end)
   sched()
end

function OpenGLApp_mt:draw()
end

function OpenGLApp_mt:done()
end

OpenGLApp_mt.__index = OpenGLApp_mt

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

function M.OpenGLApp(opts)
   opts = opts or {}
   opts.opengl = true
   local self = {
      x = opts.x or -1, -- -1 means centered
      y = opts.y or -1,
      w = opts.w or 640,
      h = opts.h or 480,
      title = opts.title or "OpenGLApp",
      fps = opts.fps or 60,
      gl_profile = opts.gl_profile or "core",
      gl_version = opts.gl_version or "3.3",
   }
   local flags = 0
   for k,v in pairs(sdl_window_flags) do
      if opts[k] then
         flags = bit.bor(flags, v)
      end
   end
   self.flags = flags
   return setmetatable(self, OpenGLApp_mt)
end

return M
