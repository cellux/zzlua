local ffi = require('ffi')
local sched = require('sched')
local sdl = require('sdl2')

local function KeyMapper(ui)
   local self = {}
   local handle_keys = true
   local keymaps = {}
   function self:push(keymap)
      table.insert(keymaps, keymap)
   end
   function self:pop()
      return table.remove(keymaps)
   end
   function self:set(keymap)
      if #keymaps == 0 then
         self.push(keymap)
      else
         keymaps[#keymaps] = keymap
      end
   end
   function self:disable()
      handle_keys = false
   end
   local function handle(key)
      -- key might be a number or a string
      --
      -- number: key code
      -- string: input text (UTF-8)
      if not handle_keys then return end
      for i=#keymaps,1,-1 do
         local keymap = keymaps[i]
         if keymap then
            local handler
            if type(keymap)=="table" then
               handler = keymap[key]
            elseif type(keymap)=="function" then
               handler = keymap
            end
            if handler then
               local mod_state = sdl.GetModState()
               local mod = {
                  ctrl = bit.band(mod_state, sdl.KMOD_CTRL) ~= 0,
                  shift = bit.band(mod_state, sdl.KMOD_SHIFT) ~= 0,
                  alt = bit.band(mod_state, sdl.KMOD_ALT) ~= 0,
               }
               local propagate_further = handler(key, mod)
               if not propagate_further then break end
            end
         end
      end
   end
   local function handle_keydown(evdata)
      handle(evdata.key.keysym.sym)
   end
   sched.on('sdl.keydown', handle_keydown)
   local function handle_textinput(evdata)
      handle(ffi.string(evdata.text.text))
   end
   sched.on('sdl.textinput', handle_textinput)
   return self
end

return KeyMapper
