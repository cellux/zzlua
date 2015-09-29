local base = require('ui.base')
local util = require('util')

local M = {}

local UI = util.Class(base.UI)

function UI:create(window)
   local self = base.UI()
   self.window = window
   self.rect.w,self.rect.h = window:GetWindowSize()
   return self
end

function UI:dpi()
   return self.window:dpi()
end

M.UI = UI

local M_mt = {}

function M_mt:__call(...)
   return UI(...)
end

return setmetatable(M, M_mt)
