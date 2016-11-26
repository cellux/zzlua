local UI = {}

function UI.Box(ui, opts)
   local self = ui:Container(opts)
   if not self.direction then
      error("UI.Box needs direction")
   end
   function self:set_preferred_size()
      self.preferred_size.w = 0
      self.preferred_size.h = 0
      if self.direction == "h" then
         for _,widget in ipairs(self.children) do
            widget:set_preferred_size()
            if widget.preferred_size.h > self.preferred_size.h then
               self.preferred_size.h = widget.preferred_size.h
            end
         end
      elseif self.direction == "v" then
         for _,widget in ipairs(self.children) do
            widget:set_preferred_size()
            if widget.preferred_size.w > self.preferred_size.w then
               self.preferred_size.w = widget.preferred_size.w
            end
         end
      else
         ef("invalid pack direction: %s", self.direction)
      end
   end
   function self:layout()
      local cx, cy = self.rect.x, self.rect.y
      local cw, ch = self.rect.w, self.rect.h
      local n_dyn_w = 0 -- number of widgets without explicit width
      local n_dyn_h = 0 -- number of widgets without explicit height
      -- remaining width/height for dynamically sized widgets
      local dyn_w, dyn_h = cw, ch
      -- we subtract all explicit widths/heights to get the remaining
      -- space which will be divided evenly among dynamic widgets
      for _,widget in ipairs(self.children) do
         if widget.preferred_size.w > 0 then
            dyn_w = dyn_w - widget.preferred_size.w
         else
            n_dyn_w = n_dyn_w + 1
         end
         if widget.preferred_size.h > 0 then
            dyn_h = dyn_h - widget.preferred_size.h
         else
            n_dyn_h = n_dyn_h + 1
         end
      end
      if dyn_w < 0 then
         dyn_w = 0
      end
      if dyn_h < 0 then
         dyn_h = 0
      end
      -- pack children
      local x,y = cx,cy
      for _,widget in ipairs(self.children) do
         widget.rect.x = x
         widget.rect.y = y
         if self.direction == "h" then
            if widget.preferred_size.w > 0 then
               widget.rect.w = widget.preferred_size.w
            else
               widget.rect.w = dyn_w / n_dyn_w
            end
            widget.rect.h = ch
            x = x + widget.rect.w
         elseif self.direction == "v" then
            widget.rect.w = cw
            if widget.preferred_size.h > 0 then
               widget.rect.h = widget.preferred_size.h
            else
               widget.rect.h = dyn_h / n_dyn_h
            end
            y = y + widget.rect.h
         else
            ef("invalid pack direction: %s", self.direction)
         end
      end
   end
   return self
end

function UI.HBox(ui, opts)
   opts = opts or {}
   opts.direction = "h"
   return ui:Box(opts)
end

function UI.VBox(ui, opts)
   opts = opts or {}
   opts.direction = "v"
   return ui:Box(opts)
end

return UI
