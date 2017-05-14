local gl = require('gl')
local sdl = require('sdl2')
local util = require('util')
local sched = require('sched')
local time = require('time')
local trigger = require('trigger')

-- preload freetype to ensure it's initialized by the scheduler
require('freetype')

local M = {}

-- Object

local Object = util.Class()

function Object:create(opts)
   local self = opts or {}
   return self
end

function Object:delete()
   -- finalizer
end

-- Widget

local Widget = util.Class(Object)

function Widget:create(opts)
   local self = Object(opts)
   -- the post-layout location of the widget in screen cordinates
   -- this will be updated by self.parent:layout()
   self.rect = Rect(0,0,0,0)
   -- the preferred size of the widget, nil means undefined
   self.preferred_size = nil
   return self
end

function Widget:set_preferred_size()
   -- update self.preferred_size here
end

function Widget:draw()
   -- draw the widget so that it fills self.rect
end

function Widget:redraw()
   -- bubble ourselves up through the parent chain until we find a
   -- container with selective_redraw = true
   --
   -- that container will put this widget into its redraw_list which
   -- ensures that self:draw() will be called at the next opportunity
   if self.parent then
      self.parent:redraw(self)
   end
end

M.Widget = Widget

-- Container

local Container = util.Class(Widget)

function Container:create(opts)
   local self = Widget(opts)
   self.children = {}
   if self.selective_redraw then
      -- redraw_list is the list of descendant widgets which should be
      -- drawn at the next draw() call
      self.redraw_list = {}
      -- if force_draw is true, self:draw() will unconditionally
      -- draw() all children and then resets force_draw to false
      --
      -- we want a complete repaint on the first draw() call, so we
      -- set this to true
      self.force_draw = true
   end
   return self
end

function Container:add(widget)
   widget.parent = self
   table.insert(self.children, widget)
end

function Container:set_preferred_size()
   -- bottom -> up
   self.preferred_size = Size(0,0)
   for _,widget in ipairs(self.children) do
      widget:set_preferred_size()
      local wps = widget.preferred_size
      if wps and wps.w > self.preferred_size.w then
         self.preferred_size.w = wps.w
      end
      if wps and wps.h > self.preferred_size.h then
         self.preferred_size.h = wps.h
      end
   end
end

function Container:layout(layout_rect)
   -- callers may override the rect in which children are laid out
   layout_rect = layout_rect or self.rect
   -- top -> down
   if not self.preferred_size then
      self:set_preferred_size()
   end
   for _,widget in ipairs(self.children) do
      widget.rect.x = layout_rect.x
      widget.rect.y = layout_rect.y
      local wps = widget.preferred_size
      if wps and wps.w > 0 then
         widget.rect.w = wps.w
      else
         widget.rect.w = layout_rect.w
      end
      if wps and wps.h > 0 then
         widget.rect.h = wps.h
      else
         widget.rect.h = layout_rect.h
      end
      if widget.layout then
         widget:layout()
      end
   end
end

function Container:draw()
   if self.selective_redraw and not self.force_draw then
      for _,widget in ipairs(self.redraw_list) do
         widget:draw()
      end
      self.redraw_list = {}
   else
      for _,widget in ipairs(self.children) do
         widget:draw()
      end
      self.force_draw = false
   end
end

function Container:redraw(widget)
   if self.selective_redraw and widget then
      table.insert(self.redraw_list, widget)
   end
   if self.parent then
      self.parent:redraw(widget or self)
   elseif self.redraw_trigger then
      self.redraw_trigger:fire()
   end
end

function Container:delete()
   for _,widget in ipairs(self.children) do
      widget:delete()
   end
   self.children = {}
end

M.Container = Container

-- Window

M.DEFAULT_REFRESH_RATE = 60

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

local Window = util.Class(Container)

function Window:create(opts)
   local self = Container {
      selective_redraw = opts.selective_redraw
   }

   if self.selective_redraw then
      -- with selective_redraw == true, the window render loop blocks
      -- after each draw operation waiting for the next redraw trigger
      self.redraw_trigger = trigger()
   end

   local x = opts.x or -1 -- -1 means centered
   local y = opts.y or -1
   local width = opts.width or sdl.DEFAULT_WINDOW_WIDTH
   local height = opts.height or sdl.DEFAULT_WINDOW_HEIGHT
   local title = opts.title or "Window"
   local gl_profile = opts.gl_profile or 'es'
   local gl_version = opts.gl_version

   if not gl_version then
      if gl_profile == 'core' then
         gl_version = '3.0'
      elseif gl_profile == 'es' then
         gl_version = '2.0'
      else
         error("no default gl_version for the compatibility profile")
      end
   end

   local flags = 0
   for k,v in pairs(sdl_window_flags) do
      if opts[k] then
         flags = bit.bor(flags, v)
      end
   end

   -- we need OpenGL
   flags = bit.bor(flags, sdl.SDL_WINDOW_OPENGL)

   -- start hidden, call show() when everything is ready
   flags = bit.bor(flags, sdl.SDL_WINDOW_HIDDEN)

   sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, resolve_gl_profile_mask(gl_profile))

   local major, minor = parse_gl_version(gl_version)
   sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, major)
   sdl.GL_SetAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, minor)

   sdl.GL_SetAttribute(sdl.SDL_GL_DOUBLEBUFFER, 1)

   self.window = sdl.CreateWindow(title, x, y, width, height, flags)
   assert(gl.GetError() == gl.GL_NO_ERROR)

   self.ctx = self.window:GL_CreateContext()
   assert(gl.GetError() == gl.GL_NO_ERROR)

   self.ctx:GL_MakeCurrent()
   assert(gl.GetError() == gl.GL_NO_ERROR)

   sdl.SDL_GL_SetSwapInterval(1)
   assert(sdl.SDL_GL_GetSwapInterval()==1)

   if opts.quit_on_escape then
      local function quit_on_escape(evdata)
         if evdata.key.keysym.sym == sdl.SDLK_ESCAPE then
            sched.quit()
         end
      end
      sched.on('sdl.keydown', quit_on_escape)
   end

   return self
end

function Window:dpi()
   return self.window:dpi()
end

function Window:fps()
   local mode = self.window:GetWindowDisplayMode()
   if mode.refresh_rate == 0 then
      pf("Warning: cannot determine screen refresh rate, using default (%d)", M.DEFAULT_REFRESH_RATE)
      return M.DEFAULT_REFRESH_RATE
   else
      return mode.refresh_rate
   end
end

function Window:update_rect()
   self.rect.w, self.rect.h = self.window:GetWindowSize()
end

function Window:resize(new_width, new_height)
   if new_width or new_height then
      -- TODO: resize window
   end
   self:update_rect()
   self:layout()
end

function Window:show()
   self.window:ShowWindow()
   -- from this point on we have an actual size
   self:update_rect()
end

function Window:clear(color)
   if color then
      gl.ClearColor(color:floats())
   end
   gl.Clear(gl.GL_COLOR_BUFFER_BIT)
end

function Window:draw()
   self.ctx:GL_MakeCurrent()
   gl.Viewport(self.rect.x, self.rect.y, self.rect.w, self.rect.h)
   Container.draw(self)
end

function Window:present()
   self.window:GL_SwapWindow()
end

function Window.RenderLoop(window, opts)
   opts = opts or {}
   local fps = opts.fps or window:fps()
   local frame_time = opts.frame_time or 0
   local acc_types = {
      'prepare',
      'clear',
      'draw',
      'present',
      'update',
      'sleep'
   }
   local acc = {}
   for _,acc_type in ipairs(acc_types) do
      acc[acc_type] = util.Accumulator()
   end
   local running = false
   local self = {}
   function self:prepare()
   end
   function self:clear()
      window:clear()
   end
   function self:draw()
      window:draw()
   end
   function self:update(dt)
   end
   local measure
   if opts.measure then
      measure = function(fn, acc_type)
         local t1 = time.time()
         fn()
         local t2 = time.time()
         acc[acc_type]:feed(t2-t1)
      end
      sched.on('quit', function() self:print_stats() end)
   else
      measure = function(fn) fn() end
   end
   function self:start()
      local now = sched.now
      running = true
      while running do
         local prev_now = now
         now = sched.now
         measure(function() self:prepare() end, 'prepare')
         measure(function() self:clear() end, 'clear')
         measure(function() self:draw() end, 'draw')
         local gl_error = gl.GetError()
         if gl_error ~= gl.GL_NO_ERROR then
            ef("GL error: %x", gl_error)
         end
         measure(function() window:present() end, 'present')
         local dt = now - prev_now
         measure(function() self:update(dt) end, 'update')
         if window.redraw_trigger then
            -- block until something needs to be redrawn
            measure(function() window.redraw_trigger:poll() end, 'sleep')
         else
            if frame_time > 0 then
               local next_frame_start = now + frame_time
               measure(function() sched.wait(next_frame_start) end, 'sleep')
            else
               measure(function() sched.yield() end, 'sleep')
            end
         end
      end
   end
   function self:stop()
      running = false
   end
   function self:print_stats()
      for _,acc_type in ipairs(acc_types) do
         pf("%-8s: %.8f seconds", acc_type, acc[acc_type].avg)
      end
   end
   return setmetatable(self, { __call = self.start })
end

function Window:delete()
   if self.ctx ~= nil then
      self.ctx:GL_DeleteContext()
      self.ctx = nil
   end
   if self.window ~= nil then
      self.window:DestroyWindow()
      self.window = nil
   end
end

M.Window = Window

-- UI

local UI = util.Class(Container)

function UI:create(window)
   -- window can be:
   --
   -- a) a Window object
   -- b) config options for a new window to be created
   --
   window = window or {}
   if type(window) == "table" then
      window = Window(window)
   end
   local self = Container { window = window }
   self.pixel_byte_order = "be"
   self.pitch_sign = -1
   window:add(self)
   return self
end

function UI:show()
   self.window:show()
   self.rect.w = self.window.rect.w
   self.rect.h = self.window.rect.h
end

function UI:dpi()
   return self.window:dpi()
end

function UI:fps()
   return self.window:fps()
end

function UI:clear(color)
   self.window:clear(color)
end

function UI.Object(ui, opts)
   return Object(opts)
end

function UI.Widget(ui, opts)
   return Widget(opts)
end

function UI.Container(ui, opts)
   return Container(opts)
end

function UI.Window(ui, opts)
   return Window(opts)
end

function UI.RenderLoop(ui, opts)
   return ui.window:RenderLoop(opts)
end

-- turn UI into a factory of ui.* classes
UI = util.ClassLoader(UI, 'ui')

local M_mt = {}

function M_mt:__call(...)
   return UI(...)
end

return setmetatable(M, M_mt)
