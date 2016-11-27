local file = require('file')
local util = require('util')
local iconv = require('iconv')
local sdl = require('sdl2')

local UI = {}

function UI.GridEdit(ui, opts)
   local self = ui:Widget(opts)
   local grid = ui:CharGrid { font = opts.font }
   grid.parent = self
   local lines = {}
   local current_row = 0
   local top_row = 0
   local current_col = 0
   local left_col = 0
   local current_line, previous_line, next_line
   local current_cp, previous_cp, next_cp
   local page_size = 16
   local overwrite = false
   local needs_redraw = true
   local function redraw()
      grid:erase()
      local row = top_row
      local y = 0
      while y < grid.height and row < #lines do
         grid:write_cps(0, y, lines[row+1], left_col)
         row = row + 1
         y = y + 1
      end
      local x = current_col - left_col
      local y = current_row - top_row
      grid:bg(1)
      grid:write_char(x, y, current_cp or 0x20)
      grid:bg(0)
      needs_redraw = false
   end
   local function adjust()
      -- row
      if current_row < 0 then
         current_row = 0
      elseif current_row >= #lines then
         current_row = #lines - 1
      end
      if current_row < top_row then
         top_row = current_row
      elseif current_row - top_row >= grid.height then
         top_row = current_row - grid.height + 1
      end
      -- line
      current_line = lines[current_row+1]
      if current_row > 0 then
         previous_line = lines[current_row]
      else
         previous_line = nil
      end
      if current_row+2 <= #lines then
         next_line = lines[current_row+2]
      else
         next_line = nil
      end
      -- column
      if current_col < 0 then
         current_col = 0
      elseif current_col > #current_line then
         current_col = #current_line
      end
      if current_col < left_col then
         left_col = current_col
      elseif current_col - left_col >= grid.width then
         left_col = current_col - grid.width + 1
      end
      -- cp
      current_cp = current_line[current_col+1]
      if current_col > 0 then
         previous_cp = current_line[current_col]
      elseif current_row > 0 then
         local row = current_row-1
         while row >= 0 and #lines[row+1] == 0 do
            row = row - 1
         end
         if row >= 0 then
            local line = lines[row+1]
            previous_cp = line[#line]
         else
            previous_cp = nil
         end
      else
         previous_cp = nil
      end
      if current_col+1 < #current_line then
         next_cp = current_line[current_col+2]
      elseif current_row+1 < #lines then
         local row = current_row+1
         while row < #lines and #lines[row+1] == 0 do
            row = row + 1
         end
         if row < #lines then
            local line = lines[row+1]
            next_cp = line[1]
         else
            next_cp = nil
         end
      else
         next_cp = nil
      end
   end
   function self:layout()
      grid:layout()
      adjust()
   end
   function self:draw()
      if needs_redraw then
         redraw()
      end
      grid:draw()
   end
   function self:text(new_text)
      lines = {}
      for line in util.lines(new_text) do
         table.insert(lines, iconv.utf8_codepoints(line))
      end
      needs_redraw = true
   end
   function self:load(path)
      local text = file.read(path)
      self:text(text)
   end
   function self:line_down(steps)
      current_row = current_row + (steps or 1)
      adjust()
      needs_redraw = true
   end
   function self:line_up(steps)
      current_row = current_row - (steps or 1)
      adjust()
      needs_redraw = true
   end
   function self:page_down()
      self:line_down(page_size)
   end
   function self:page_up()
      self:line_up(page_size)
   end
   local function at_end_of_line()
      return (current_col == #current_line)
   end
   local function at_end_of_text()
      return (current_row == #lines - 1 and current_col == #current_line)
   end
   function self:start_of_line()
      current_col = 0
      adjust()
      needs_redraw = true
   end
   function self:char_right()
      if not at_end_of_text() then
         if at_end_of_line() then
            self:start_of_line()
            self:line_down()
         else
            current_col = current_col + 1
            adjust()
            needs_redraw = true
         end
      end
   end
   local function at_start_of_text()
      return (current_row == 0 and current_col == 0)
   end
   local function at_start_of_line()
      return current_col == 0
   end
   function self:end_of_line()
      current_col = #current_line
      adjust()
      needs_redraw = true
   end
   function self:char_left()
      if not at_start_of_text() then
         if at_start_of_line() then
            self:line_up()
            self:end_of_line()
         else
            current_col = current_col - 1
            adjust()
            needs_redraw = true
         end
      end
   end
   local ws_map = {}
   local function def_ws_range(lo, hi)
      for cp = lo,hi do
         ws_map[cp] = true
      end
   end
   def_ws_range(0x20,0x2f)
   def_ws_range(0x3a,0x40)
   def_ws_range(0x5b,0x60)
   ws_map[0x5f] = nil -- underscore is a word-constituent
   def_ws_range(0x7b,0x7e)
   local function is_ws(cp)
      return ws_map[cp]
   end
   function self:word_right()
      while not is_ws(current_cp) do
         self:char_right()
         if at_start_of_line() and #current_line > 0 then
            break
         end
      end
      while is_ws(current_cp) do
         self:char_right()
      end
      if at_end_of_line() then
         self:word_right()
      end
   end
   function self:word_left(step)
      step = step or function() self:char_left() end
      while is_ws(previous_cp) do
         step()
      end
      while previous_cp and not is_ws(previous_cp) do
         step()
         if at_start_of_line() and #current_line > 0 then
            break
         end
      end
   end
   function self:start_of_text()
      current_row = 0
      current_col = 0
      adjust()
      needs_redraw = true
   end
   function self:end_of_text()
      current_row = #lines - 1
      adjust()
      self:end_of_line()
   end
   function self:toggle_overwrite()
      overwrite = not overwrite
      needs_redraw = true
   end
   function self:delete_right()
      if not at_end_of_text() then
         if at_end_of_line() then
            local next_line = lines[current_row+2]
            for i=1,#next_line do
               table.insert(current_line, next_line[i])
            end
            table.remove(lines, current_row+2)
         else
            table.remove(current_line, current_col+1)
         end
         adjust()
         needs_redraw = true
      end
   end
   function self:delete_left()
      if not at_start_of_text() then
         self:char_left()
         self:delete_right()
      end
   end
   function self:delete_word_left()
      self:word_left(function() self:delete_left() end)
   end
   function self:line_break()
      local new_line = {}
      while #current_line > current_col do
         table.insert(new_line, current_line[current_col+1])
         table.remove(current_line, current_col+1)
      end
      table.insert(lines, current_row+2, new_line)
      self:start_of_line()
      self:line_down()
   end
   function self:insert(text)
      local cps = iconv.utf8_codepoints(text)
      table.insert(current_line, current_col+1, cps[1])
      self:char_right()
   end
   local control_keymap = {
      [sdl.SDLK_DOWN] = function(key, mod)
         self:line_down()
      end,
      [sdl.SDLK_UP] = function(key, mod)
         self:line_up()
      end,
      [sdl.SDLK_LEFT] = function(key, mod)
         if mod.ctrl then
            self:word_left()
         else
            self:char_left()
         end
      end,
      [sdl.SDLK_RIGHT] = function(key, mod)
         if mod.ctrl then
            self:word_right()
         else
            self:char_right()
         end
      end,
      [sdl.SDLK_END] = function(key, mod)
         if mod.ctrl then
            self:end_of_text()
         else
            self:end_of_line()
         end
      end,
      [sdl.SDLK_HOME] = function(key, mod)
         if mod.ctrl then
            self:start_of_text()
         else
            self:start_of_line()
         end
      end,
      [sdl.SDLK_PAGEUP] = function()
         self:page_up()
      end,
      [sdl.SDLK_PAGEDOWN] = function()
         self:page_down()
      end,
      [sdl.SDLK_INSERT] = function()
         self:toggle_overwrite()
      end,
      [sdl.SDLK_BACKSPACE] = function(key, mod)
         if mod.alt then
            self:delete_word_left()
         else
            self:delete_left()
         end
      end,
      [sdl.SDLK_DELETE] = function()
         self:delete_right()
      end,
      [sdl.SDLK_RETURN] = function()
         self:line_break()
      end,
   }
   self.default_keymap = function(key, mod)
      if control_keymap[key] then
         control_keymap[key](key, mod)
      elseif type(key)=="string" then
         self:insert(key)
      end
   end
   return self
end

return UI
