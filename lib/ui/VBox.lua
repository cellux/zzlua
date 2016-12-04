local function VBox(ui, opts)
   opts = opts or {}
   opts.direction = "v"
   return ui:Box(opts)
end

return VBox
