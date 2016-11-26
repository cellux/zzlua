local sched = require('sched')
local sdl = require('sdl2')

local UI = {}

function UI.KeyMapper(ui)
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
   local function handle_keydown(evdata)
      if not handle_keys then return end
      local sym = evdata.key.keysym.sym
      for i=#keymaps,1,-1 do
         local keymap = keymaps[i]
         if keymap then
            local handler
            if type(keymap)=="table" then
               handler = keymap[sym]
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
               local propagate_further = handler(sym, mod)
               if not propagate_further then break end
            end
         end
      end
   end
   sched.on('sdl.keydown', handle_keydown)
   return self
end

return UI
