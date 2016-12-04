local function HBox(ui, opts)
   opts = opts or {}
   opts.direction = "h"
   return ui:Box(opts)
end

return HBox
