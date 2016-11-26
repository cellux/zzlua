local ffi = require('ffi')
local sdl = require('sdl2')
local util = require('util')

local UI = {}

local function compile_write_row(src_components, dst_components, opts)
   local code = ""
   local function codegen(line)
      code = code..line.."\n"
   end
   local function adjust_dst_index(index)
      if opts.swap_byte_order then
         return #dst_components - index - 1
      else
         return index
      end
   end
   local function gen_copy(dst_index, src_index)
      codegen(sf("dst[%d]=src[%d]", adjust_dst_index(dst_index), src_index))
   end
   local function gen_write(dst_index, value)
      codegen(sf("dst[%d]=0x%x", adjust_dst_index(dst_index), value))
   end
   local function significant_component(c)
      return c ~= 'x'
   end
   local src_component_indices = {}
   for i=1,#src_components do
      local c = src_components:sub(i,i)
      if significant_component(c) then
         src_component_indices[c] = i-1
      end
   end
   local dst_component_indices = {}
   for i=1,#dst_components do
      local c = dst_components:sub(i,i)
      if significant_component(c) then
         dst_component_indices[c] = i-1
      end
   end
   codegen "return function(src, dst, width)"
   codegen("for i=1,width do")
   for i=1,#dst_components do
      local dst_index = i-1
      local c = dst_components:sub(i,i)
      if significant_component(c) then
         local src_index = src_component_indices[c]
         if src_index then
            gen_copy(dst_index, src_index)
         else
            if c == "a" and opts.alpha_key then
               -- alpha_key is the color which shall be transparent
               local clauses = {}
               for _,c in ipairs({"r","g","b"}) do
                  if src_component_indices[c] then
                     table.insert(clauses, sf("src[%d]==0x%x", src_component_indices[c], opts.alpha_key[c]))
                  end
               end
               if #clauses > 0 then
                  codegen(sf("if %s then", table.concat(clauses, " and ")))
                  gen_write(dst_index, 0x00) -- transparent
                  codegen "else"
                  gen_write(dst_index, 0xff) -- opaque
                  codegen "end"
               else
                  error("set alpha_key, but there are no source pixel components to match: %s", src_components)
               end
            else
               -- this component won't be set
            end
         end
      end
   end
   codegen(sf("src=src+%d", #src_components))
   codegen(sf("dst=dst+%d", #dst_components))
   codegen "end" -- for i=1,width do
   codegen "end" -- function(src, dst, width)
   --print(code)
   return assert(loadstring(code))()
end

local pixelformat2components_map = {
   [sdl.SDL_PIXELFORMAT_RGBA8888] = "rgba",
   [sdl.SDL_PIXELFORMAT_RGB24] = "rgb",
}

local function pixelformat2components(format)
   if type(format) == "string" then
      -- it's already a string of component markers
      return format
   else
      local components = pixelformat2components_map[format]
      if not components then
         ef("unknown components for pixel format %x", format)
      end
      return components
   end
end

local function make_write_row(src_format, dst_format, opts)
   local src_components = pixelformat2components(src_format)
   local dst_components = pixelformat2components(dst_format)
   return compile_write_row(src_components, dst_components, opts)
end

function UI.PixelBuffer(ui, format, width, height, buf, pitch_sign)
   local self = {
      is_pixelbuffer = true, -- very primitive (but fast) type id
      format = format,
      width = width,
      height = height,
      rect = Rect(0, 0, width, height),
      pitch_sign = pitch_sign or ui.pitch_sign,
   }
   -- we only deal with pixels formats supported by GLES 2:
   -- ALPHA, LUMINANCE, LUMINANCE_ALPHA, RGB, RGBA
   self.bits_per_pixel = 8
   self.bytes_per_pixel = #format
   self.pitch = util.align_up(self.width * self.bytes_per_pixel, 4)
   self.buf = buf or ffi.new("uint8_t[?]", self.pitch * self.height)
   function self:Writer(opts)
      local src_format = opts.format
      local dst_format = self.format
      local writer = {
         dst = self.buf,
         width = self.width,
         height = self.height,
         pitch = self.pitch,
      }
      if self.pitch_sign == -1 then
         -- rows should be filled from bottom to top
         writer.dst = self.buf + (self.height-1) * self.pitch
         writer.pitch = -self.pitch
      end
      local write_row = make_write_row(src_format, dst_format, opts)
      function writer:write_row(src)
         write_row(src, self.dst, self.width)
         self.dst = self.dst + self.pitch
      end
      function writer:write(pixels, pitch)
         for i=0,self.height-1 do
            self:write_row(pixels+i*pitch)
         end
      end
      return writer
   end
   return self
end

return UI
