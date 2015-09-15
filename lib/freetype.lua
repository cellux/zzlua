local ffi = require('ffi')
local bit = require('bit')
local util = require('util')
local sched = require('sched')

local function ft_tag_to_u32(tag)
   return bit.bor(bit.lshift(tag:byte(1),24),
                  bit.lshift(tag:byte(2),16),
                  bit.lshift(tag:byte(3),8),
                  tag:byte(4))
end

-- generate C source for the definition of the FT_Encoding enum type

local ft_encodings = {
  FT_ENCODING_NONE = '\0\0\0\0',
  FT_ENCODING_MS_SYMBOL = 'symb',
  FT_ENCODING_UNICODE = 'unic',
  FT_ENCODING_SJIS = 'sjis',
  FT_ENCODING_GB2312 = 'gb  ',
  FT_ENCODING_BIG5 = 'big5',
  FT_ENCODING_WANSUNG = 'wans',
  FT_ENCODING_JOHAB = 'joha',
  FT_ENCODING_MS_SJIS = 'sjis',
  FT_ENCODING_MS_GB2312 = 'gb  ',
  FT_ENCODING_MS_BIG5 = 'big5',
  FT_ENCODING_MS_WANSUNG = 'wans',
  FT_ENCODING_MS_JOHAB = 'joha',
  FT_ENCODING_ADOBE_STANDARD = 'ADOB',
  FT_ENCODING_ADOBE_EXPERT = 'ADBE',
  FT_ENCODING_ADOBE_CUSTOM = 'ADBC',
  FT_ENCODING_ADOBE_LATIN_1 = 'lat1',
  FT_ENCODING_OLD_LATIN_2 = 'lat2',
  FT_ENCODING_APPLE_ROMAN = 'armn',
}

local ft_encoding_cdef = "typedef enum FT_Encoding_ {\n"
for name,tag in pairs(ft_encodings) do
   ft_encoding_cdef = ft_encoding_cdef .. sf("  %s = 0x%04x,\n",
                                             name,
                                             ft_tag_to_u32(tag))
end
ft_encoding_cdef = ft_encoding_cdef .. "  FT_ENCODING_LAST\n} FT_Encoding;\n"
ffi.cdef(ft_encoding_cdef)

-- generate C source for the definition of the FT_Glyph_Format enum type

local ft_glyph_formats = {
  FT_GLYPH_FORMAT_NONE = '\0\0\0\0',
  FT_GLYPH_FORMAT_COMPOSITE = 'comp',
  FT_GLYPH_FORMAT_BITMAP = 'bits',
  FT_GLYPH_FORMAT_OUTLINE = 'outl',
  FT_GLYPH_FORMAT_PLOTTER = 'plot',
}

local ft_glyph_format_cdef = "typedef enum FT_Glyph_Format_ {\n"
for name,tag in pairs(ft_glyph_formats) do
   ft_glyph_format_cdef = ft_glyph_format_cdef .. sf("  %s = 0x%04x,\n",
                                                     name,
                                                     ft_tag_to_u32(tag))
end
ft_glyph_format_cdef = ft_glyph_format_cdef .. "  FT_GLYPH_FORMAT_LAST\n} FT_Glyph_Format;\n"
ffi.cdef(ft_glyph_format_cdef)

-- now the rest of the cdefs

ffi.cdef [[

typedef int             FT_Error;

typedef unsigned char   FT_Byte;
typedef signed short    FT_Short;
typedef unsigned short  FT_UShort;
typedef signed int      FT_Int;
typedef unsigned int    FT_UInt;
typedef int32_t         FT_Int32;
typedef uint32_t        FT_UInt32;
typedef signed long     FT_Long;
typedef unsigned long   FT_ULong;

typedef char            FT_String;
typedef signed long     FT_Pos;
typedef signed long     FT_Fixed;
typedef signed short    FT_F2Dot14;
typedef signed long     FT_F26Dot6;

typedef struct FT_LibraryRec_  *FT_Library;
typedef struct FT_FaceRec_*  FT_Face;
typedef struct FT_CharMapRec_*  FT_CharMap;
typedef struct FT_Face_InternalRec_*  FT_Face_Internal;
typedef struct FT_GlyphSlotRec_*  FT_GlyphSlot;
typedef struct FT_SubGlyphRec_*  FT_SubGlyph;
typedef struct FT_Slot_InternalRec_*  FT_Slot_Internal;
typedef struct FT_SizeRec_*  FT_Size;
typedef struct FT_Size_InternalRec_*  FT_Size_Internal;

typedef struct  FT_BBox_ {
  FT_Pos  xMin, yMin;
  FT_Pos  xMax, yMax;
} FT_BBox;

typedef struct  FT_Vector_ {
  FT_Pos  x;
  FT_Pos  y;
} FT_Vector;

typedef struct  FT_Bitmap_Size_ {
  FT_Short  height;
  FT_Short  width;
  FT_Pos    size;
  FT_Pos    x_ppem;
  FT_Pos    y_ppem;
} FT_Bitmap_Size;

typedef struct  FT_Bitmap_ {
  unsigned int    rows;
  unsigned int    width;
  int             pitch;
  unsigned char*  buffer;
  unsigned short  num_grays;
  unsigned char   pixel_mode;
  unsigned char   palette_mode;
  void*           palette;
} FT_Bitmap;

typedef struct  FT_Outline_ {
  short       n_contours;      /* number of contours in glyph        */
  short       n_points;        /* number of points in the glyph      */

  FT_Vector*  points;          /* the outline's points               */
  char*       tags;            /* the points flags                   */
  short*      contours;        /* the contour end points             */

  int         flags;           /* outline masks                      */
} FT_Outline;

typedef struct  FT_CharMapRec_ {
  FT_Face      face;
  FT_Encoding  encoding;
  FT_UShort    platform_id;
  FT_UShort    encoding_id;
} FT_CharMapRec;

typedef void  (*FT_Generic_Finalizer)(void*  object);
typedef struct  FT_Generic_ {
  void*                 data;
  FT_Generic_Finalizer  finalizer;
} FT_Generic;

typedef struct  FT_Glyph_Metrics_
{
  FT_Pos  width;
  FT_Pos  height;

  FT_Pos  horiBearingX;
  FT_Pos  horiBearingY;
  FT_Pos  horiAdvance;

  FT_Pos  vertBearingX;
  FT_Pos  vertBearingY;
  FT_Pos  vertAdvance;
} FT_Glyph_Metrics;

typedef struct  FT_GlyphSlotRec_ {
  FT_Library        library;
  FT_Face           face;
  FT_GlyphSlot      next;
  FT_UInt           reserved;       /* retained for binary compatibility */
  FT_Generic        generic;

  FT_Glyph_Metrics  metrics;
  FT_Fixed          linearHoriAdvance;
  FT_Fixed          linearVertAdvance;
  FT_Vector         advance;

  FT_Glyph_Format   format;

  FT_Bitmap         bitmap;
  FT_Int            bitmap_left;
  FT_Int            bitmap_top;

  FT_Outline        outline;

  FT_UInt           num_subglyphs;
  FT_SubGlyph       subglyphs;

  void*             control_data;
  long              control_len;

  FT_Pos            lsb_delta;
  FT_Pos            rsb_delta;

  void*             other;

  FT_Slot_Internal  internal;
} FT_GlyphSlotRec;

typedef struct  FT_Size_Metrics_ {
  FT_UShort  x_ppem;      /* horizontal pixels per EM               */
  FT_UShort  y_ppem;      /* vertical pixels per EM                 */

  FT_Fixed   x_scale;     /* scaling values used to convert font    */
  FT_Fixed   y_scale;     /* units to 26.6 fractional pixels        */

  FT_Pos     ascender;    /* ascender in 26.6 frac. pixels          */
  FT_Pos     descender;   /* descender in 26.6 frac. pixels         */
  FT_Pos     height;      /* text height in 26.6 frac. pixels       */
  FT_Pos     max_advance; /* max horizontal advance, in 26.6 pixels */
} FT_Size_Metrics;

typedef struct  FT_SizeRec_ {
  FT_Face           face;      /* parent face object              */
  FT_Generic        generic;   /* generic pointer for client uses */
  FT_Size_Metrics   metrics;   /* size metrics                    */
  FT_Size_Internal  internal;
} FT_SizeRec;

typedef struct  FT_FaceRec_ {
  FT_Long           num_faces;
  FT_Long           face_index;

  FT_Long           face_flags;
  FT_Long           style_flags;

  FT_Long           num_glyphs;

  FT_String*        family_name;
  FT_String*        style_name;

  FT_Int            num_fixed_sizes;
  FT_Bitmap_Size*   available_sizes;

  FT_Int            num_charmaps;
  FT_CharMap*       charmaps;

  FT_Generic        generic;

  /*# The following member variables (down to `underline_thickness') */
  /*# are only relevant to scalable outlines; cf. @FT_Bitmap_Size    */
  /*# for bitmap fonts.                                              */
  FT_BBox           bbox;

  FT_UShort         units_per_EM;
  FT_Short          ascender;
  FT_Short          descender;
  FT_Short          height;

  FT_Short          max_advance_width;
  FT_Short          max_advance_height;

  FT_Short          underline_position;
  FT_Short          underline_thickness;

  FT_GlyphSlot      glyph;
  FT_Size           size;
  FT_CharMap        charmap;

  /*@private begin

  -- as we never allocate an FT_FaceRec directly, it's not a problem
  -- if the FFI thinks this struct is smaller than it actually is

  FT_Driver         driver;
  FT_Memory         memory;
  FT_Stream         stream;

  FT_ListRec        sizes_list;

  FT_Generic        autohint;
  void*             extensions;

  FT_Face_Internal  internal;

  @private end */

} FT_FaceRec;

typedef enum FT_Render_Mode_ {
  FT_RENDER_MODE_NORMAL = 0,
  FT_RENDER_MODE_LIGHT,
  FT_RENDER_MODE_MONO,
  FT_RENDER_MODE_LCD,
  FT_RENDER_MODE_LCD_V,
  FT_RENDER_MODE_MAX
} FT_Render_Mode;

typedef enum {
  FT_LOAD_TARGET_NORMAL = 0,
  FT_LOAD_TARGET_LIGHT  = 0x00010000,
  FT_LOAD_TARGET_MONO   = 0x00020000,
  FT_LOAD_TARGET_LCD    = 0x00030000,
  FT_LOAD_TARGET_LCD_V  = 0x00040000
};

enum {
  FT_LOAD_DEFAULT                      = 0,
  FT_LOAD_NO_SCALE                     = ( 1 << 0 ),
  FT_LOAD_NO_HINTING                   = ( 1 << 1 ),
  FT_LOAD_RENDER                       = ( 1 << 2 ),
  FT_LOAD_NO_BITMAP                    = ( 1 << 3 ),
  FT_LOAD_VERTICAL_LAYOUT              = ( 1 << 4 ),
  FT_LOAD_FORCE_AUTOHINT               = ( 1 << 5 ),
  FT_LOAD_CROP_BITMAP                  = ( 1 << 6 ),
  FT_LOAD_PEDANTIC                     = ( 1 << 7 ),
  FT_LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH  = ( 1 << 9 ),
  FT_LOAD_NO_RECURSE                   = ( 1 << 10 ),
  FT_LOAD_IGNORE_TRANSFORM             = ( 1 << 11 ),
  FT_LOAD_MONOCHROME                   = ( 1 << 12 ),
  FT_LOAD_LINEAR_DESIGN                = ( 1 << 13 ),
  FT_LOAD_NO_AUTOHINT                  = ( 1 << 15 ),
  FT_LOAD_COLOR                        = ( 1 << 20 )
};

FT_Error FT_Init_FreeType( FT_Library *alibrary );
FT_Error FT_Done_FreeType( FT_Library library );

FT_Error FT_New_Face( FT_Library library,
                      const char* filepathname,
                      FT_Long face_index,
                      FT_Face *aface );
FT_Error FT_New_Memory_Face( FT_Library library,
                             const FT_Byte* file_base,
                             FT_Long file_size,
                             FT_Long face_index,
                             FT_Face *aface );
FT_Error FT_Set_Char_Size( FT_Face face,
                           FT_F26Dot6 char_width,
                           FT_F26Dot6 char_height,
                           FT_UInt horz_resolution,
                           FT_UInt vert_resolution );
FT_Error FT_Set_Pixel_Sizes( FT_Face face,
                             FT_UInt pixel_width,
                             FT_UInt pixel_height );
FT_Int FT_Get_Char_Index( FT_Face face, FT_ULong charcode );
FT_Error FT_Load_Glyph(FT_Face face, FT_UInt glyph_index, FT_Int32 load_flags);
FT_Error FT_Render_Glyph(FT_GlyphSlot slot, FT_Render_Mode render_mode);
FT_Error FT_Load_Char(FT_Face face, FT_ULong charcode, FT_Int32 load_flags);
FT_Error FT_Done_Face( FT_Face face );

typedef enum FT_LcdFilter_ {
  FT_LCD_FILTER_NONE    = 0,
  FT_LCD_FILTER_DEFAULT = 1,
  FT_LCD_FILTER_LIGHT   = 2,
  FT_LCD_FILTER_LEGACY  = 16,
  FT_LCD_FILTER_MAX
} FT_LcdFilter;

FT_Error FT_Library_SetLcdFilter(FT_Library library, FT_LcdFilter filter);
FT_Error FT_Library_SetLcdFilterWeights(FT_Library library,
                                        unsigned char *weights);

]]

local freetype = ffi.load("freetype")

local library = ffi.new("FT_Library[1]")

local function assert_library_loaded()
   if library[0] == nil then
      ef("FreeType functions can be used only after a call to freetype.init()")
   end
end

local M = {}

M.lcdfilter = freetype.FT_LCD_FILTER_LIGHT

local Face_mt = {}

function Face_mt:Set_Char_Size(width, height, xdpi, ydpi)
   util.check_ok("FT_Set_Char_Size", 0,
                 freetype.FT_Set_Char_Size(self.face,
                                           width or 0,
                                           height or 0,
                                           xdpi or 0,
                                           ydpi or 0))
end

function Face_mt:Set_Pixel_Sizes(width, height)
   util.check_ok("FT_Set_Pixel_Sizes", 0,
                 freetype.FT_Set_Pixel_Sizes(self.face,
                                             width or 0,
                                             height or 0))
end

-- charcode is the value of a Unicode code point (unsigned long)
function Face_mt:Get_Char_Index(charcode)
   return freetype.FT_Get_Char_Index(self.face, charcode)
end

function Face_mt:Load_Glyph(glyph_index, load_flags)
   load_flags = load_flags or freetype.FT_LOAD_DEFAULT
   util.check_ok("FT_Load_Glyph", 0,
                 freetype.FT_Load_Glyph(self.face,
                                        glyph_index,
                                        load_flags))
end

function Face_mt:Render_Glyph(render_mode)
   render_mode = render_mode or freetype.FT_RENDER_MODE_NORMAL
   util.check_ok("FT_Render_Glyph", 0,
                 freetype.FT_Render_Glyph(self.face.glyph, render_mode))
end

function Face_mt:Load_Char(charcode, load_flags)
   load_flags = load_flags or freetype.FT_LOAD_DEFAULT
   util.check_ok("FT_Load_Char", 0,
                 freetype.FT_Load_Char(self.face, charcode, load_flags))
end

function Face_mt:Done_Face()
   if self.face then
      util.check_ok("FT_Done_Face", 0, freetype.FT_Done_Face(self.face))
      self.face = nil
   end
end

Face_mt.__index = Face_mt
Face_mt.__gc = Face_mt.Done_Face

function M.New_Face(path, face_index)
   assert_library_loaded()
   face_index = face_index or 0
   local face = ffi.new("FT_Face[1]")
   util.check_ok("FT_New_Face", 0,
                 freetype.FT_New_Face(library[0], path, face_index, face))
   local self = { face = face[0] }
   return setmetatable(self, Face_mt)
end

function M.New_Memory_Face(buffer, size, face_index)
   assert_library_loaded()
   face_index = face_index or 0
   local face = ffi.new("FT_Face[1]")
   util.check_ok("FT_New_Memory_Face", 0,
                 freetype.FT_New_Memory_Face(library[0], buffer, size, face_index, face))
   local self = { face = face[0] }
   -- keep a reference to the buffer to avoid GC (FreeType needs it)
   self.buffer = buffer
   return setmetatable(self, Face_mt)
end

function M.Face(source, ...)
   if type(source)=="string" then
      return M.New_Face(source, ...)
   elseif type(source)=="cdata" then
      return M.New_Memory_Face(source, ...)
   else
      ef("First arg to freetype.Face() must be a pathname or a memory buffer")
   end
end

function M.Init_FreeType()
   assert(library[0]==nil)
   if freetype.FT_Init_FreeType(library) ~= 0 then
      ef("Cannot initialize FreeType")
   end
   if M.lcdfilter ~= freetype.FT_LCD_FILTER_NONE then
      if freetype.FT_Library_SetLcdFilter(library[0], M.lcdfilter) ~= 0 then
         ef("FT_Library_SetLcdFilter() failed")
      end
   end
end

function M.Done_FreeType()
   assert(library[0] ~= nil)
   freetype.FT_Done_FreeType(library[0])
   library[0] = nil
end

local function FreeTypeModule(sched)
   local self = {}
   self.init = M.Init_FreeType
   self.done = M.Done_FreeType
   return self
end

sched.register_module(FreeTypeModule)

return setmetatable(M, { __index = freetype })
