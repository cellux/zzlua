local function Box(ui, opts)
   local self = ui:Container(opts)
   if not self.direction then
      error("UI.Box needs direction")
   end
   function self:set_preferred_size()
      self.preferred_size = Size(0,0)
      if self.direction == "h" then
         for _,widget in ipairs(self.children) do
            widget:set_preferred_size()
            local wps = widget.preferred_size
            if wps and wps.h > self.preferred_size.h then
               self.preferred_size.h = wps.h
            end
         end
      elseif self.direction == "v" then
         for _,widget in ipairs(self.children) do
            widget:set_preferred_size()
            local wps = widget.preferred_size
            if wps and wps.w > self.preferred_size.w then
               self.preferred_size.w = wps.w
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
         local wps = widget.preferred_size
         if wps and wps.w > 0 then
            dyn_w = dyn_w - wps.w
         else
            n_dyn_w = n_dyn_w + 1
         end
         if wps and wps.h > 0 then
            dyn_h = dyn_h - wps.h
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
         local wps = widget.preferred_size
         if self.direction == "h" then
            if wps and wps.w > 0 then
               widget.rect.w = wps.w
            else
               widget.rect.w = dyn_w / n_dyn_w
            end
            widget.rect.h = ch
            x = x + widget.rect.w
         elseif self.direction == "v" then
            widget.rect.w = cw
            if wps and wps.h > 0 then
               widget.rect.h = wps.h
            else
               widget.rect.h = dyn_h / n_dyn_h
            end
            y = y + widget.rect.h
         else
            ef("invalid pack direction: %s", self.direction)
         end
         if widget.layout then
            widget:layout()
         end
      end
   end
   return self
end

return Box
