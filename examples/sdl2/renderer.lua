#!/usr/bin/env zzlua

local ffi = require('ffi')
local engine = require('engine')
local sched = require('sched')
local sdl = require('sdl2')

local app = engine.DesktopApp {
   title = "renderer-test",
}

function app:draw()
   local r = self.renderer
   r:SetRenderDrawColor(255,0,0,255)
   r:RenderClear()
end

app:run()
