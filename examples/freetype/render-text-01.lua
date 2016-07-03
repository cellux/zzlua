#!/usr/bin/env zzlua

local ffi = require('ffi')
local bit = require('bit')
local appfactory = require('appfactory')
local sched = require('sched')
local freetype = require('freetype')
local fs = require('fs')
local file = require('file')
local sdl = require('sdl2')
local iconv = require('iconv')
local time = require('time')
local round = require('util').round

local app = appfactory.DesktopApp {
   title = "render-text",
}

function app:init()
   local script_path = arg[0]
   local script_contents = file.read(script_path)
   local script_dir = fs.dirname(script_path)
   local ttf_path = fs.join(script_dir, "DejaVuSerif.ttf")
   local face = freetype.Face(ttf_path)
   local size = 20 -- initial font size in points

   local text_top = 0
   sched(function()
         while true do
            text_top = text_top-1
            sched.sleep(0.1)
         end
   end)

   local r = self.renderer
   local texture

   local function create_texture()
      -- this should be called every time the value of 'size' changes
      if texture then
         texture:DestroyTexture()
         texture = nil
      end
      face:Set_Char_Size(0, size*64, self.window:dpi())
      local max_width = round(face.face.size.metrics.max_advance/64)
      local max_height = round(face.face.size.metrics.height/64)
      -- create texture to hold glyph bitmaps
      texture = r:CreateTexture(sdl.SDL_PIXELFORMAT_RGB24,
                                sdl.SDL_TEXTUREACCESS_STATIC,
                                max_width, max_height)
   end
   create_texture()

   local function lines(s)
      local index = 1
      local function next()
         local rv = nil
         if index <= #s then
            local lf_pos = s:find("\n", index, true)
            if lf_pos then
               rv = s:sub(index, lf_pos-1)
               index = lf_pos+1
            else
               rv = s:sub(index)
               index = #s+1
            end
         end
         return rv
      end
      return next
   end

   local function draw_char(face, charcode, ox, oy)
      -- note that this is hopelessly inefficient
      face:Load_Char(charcode)
      face:Render_Glyph(freetype.FT_RENDER_MODE_LCD)
      local glyph = face.face.glyph
      local pixels = glyph.bitmap.buffer
      -- pixels can be nil when we draw a whitespace character
      if pixels ~= nil then
         local pitch = glyph.bitmap.pitch
         local width = glyph.bitmap.width/3
         local height = glyph.bitmap.rows
         local srcrect = sdl.Rect(0,0,width,height)
         texture:UpdateTexture(srcrect, pixels, pitch)
         local dstrect = sdl.Rect(ox+glyph.bitmap_left, 
                                  oy-glyph.bitmap_top,
                                  width, height)
         r:RenderCopy(texture, srcrect, dstrect)
      end
      return round(glyph.advance.x/64)
   end

   local function draw_string(face, s, x, y)
      local ascender = round(face.face.size.metrics.ascender / 64)
      local cp = iconv.utf8_codepoints(s)
      local ox = x
      local oy = y+ascender
      for i=1,#cp do
         local advance = draw_char(face, cp[i], ox, oy)
         ox = ox + advance
         if ox >= self.width then
            break
         end
      end
      return round(face.face.size.metrics.height/64)
   end

   local max_time = 0

   function app:draw()
      local t1 = time.time()
      r:SetRenderDrawColor(0,0,0,255)
      r:RenderClear()
      local top = text_top
      for line in lines(script_contents) do
         local advance = draw_string(face, line, 0, top)
         top = top + advance
         if top >= self.height then
            break
         end
      end
      local t2 = time.time()
      local elapsed = t2 - t1
      if elapsed > max_time then
         max_time = elapsed
         pf("app:draw() takes %s seconds (max)", max_time)
      end
   end

   function app:done()
      if texture then
         texture:DestroyTexture()
         texture = nil
      end
      face:Done_Face()
   end
end

app:run()
