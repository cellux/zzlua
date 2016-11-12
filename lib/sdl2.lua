local ffi = require('ffi')
local bit = require('bit')
local sched = require('sched')
local util = require('util')
local xlib = require('xlib')

ffi.cdef [[

/* SDL_types.h */

typedef enum {
  SDL_FALSE = 0,
  SDL_TRUE = 1
} SDL_bool;

typedef int8_t   Sint8;
typedef uint8_t  Uint8;
typedef int16_t  Sint16;
typedef uint16_t Uint16;
typedef int32_t  Sint32;
typedef uint32_t Uint32;
typedef int64_t  Sint64;
typedef uint64_t Uint64;

/* SDL_error.h */

const char * SDL_GetError(void);
void SDL_ClearError(void);

/* SDL_version.h */

typedef struct SDL_version {
  Uint8 major;        /**< major version */
  Uint8 minor;        /**< minor version */
  Uint8 patch;        /**< update version */
} SDL_version;

void SDL_GetVersion (SDL_version * ver);

/* SDL_platform.h */

const char * SDL_GetPlatform (void);

/* SDL_cpuinfo.h */

int SDL_GetSystemRAM (void);
int SDL_GetCPUCount (void);

/* SDL.h */

enum {
  SDL_INIT_TIMER          = 0x00000001,
  SDL_INIT_AUDIO          = 0x00000010,
  SDL_INIT_VIDEO          = 0x00000020,
  SDL_INIT_JOYSTICK       = 0x00000200,
  SDL_INIT_HAPTIC         = 0x00001000,
  SDL_INIT_GAMECONTROLLER = 0x00002000,
  SDL_INIT_EVENTS         = 0x00004000,
  SDL_INIT_NOPARACHUTE    = 0x00100000,
  SDL_INIT_EVERYTHING     = ( SDL_INIT_TIMER    |
                              SDL_INIT_AUDIO    |
                              SDL_INIT_VIDEO    |
                              SDL_INIT_EVENTS   |
                              SDL_INIT_JOYSTICK |
                              SDL_INIT_HAPTIC   |
                              SDL_INIT_GAMECONTROLLER )
};

int SDL_Init (Uint32 flags);
int SDL_InitSubSystem (Uint32 flags);
void SDL_QuitSubSystem (Uint32 flags);
Uint32 SDL_WasInit (Uint32 flags);
void SDL_Quit(void);

/* SDL_scancode.h */

typedef enum {
  SDL_SCANCODE_UNKNOWN            = 0,

  SDL_SCANCODE_A                  = 4,
  SDL_SCANCODE_B                  = 5,
  SDL_SCANCODE_C                  = 6,
  SDL_SCANCODE_D                  = 7,
  SDL_SCANCODE_E                  = 8,
  SDL_SCANCODE_F                  = 9,
  SDL_SCANCODE_G                  = 10,
  SDL_SCANCODE_H                  = 11,
  SDL_SCANCODE_I                  = 12,
  SDL_SCANCODE_J                  = 13,
  SDL_SCANCODE_K                  = 14,
  SDL_SCANCODE_L                  = 15,
  SDL_SCANCODE_M                  = 16,
  SDL_SCANCODE_N                  = 17,
  SDL_SCANCODE_O                  = 18,
  SDL_SCANCODE_P                  = 19,
  SDL_SCANCODE_Q                  = 20,
  SDL_SCANCODE_R                  = 21,
  SDL_SCANCODE_S                  = 22,
  SDL_SCANCODE_T                  = 23,
  SDL_SCANCODE_U                  = 24,
  SDL_SCANCODE_V                  = 25,
  SDL_SCANCODE_W                  = 26,
  SDL_SCANCODE_X                  = 27,
  SDL_SCANCODE_Y                  = 28,
  SDL_SCANCODE_Z                  = 29,

  SDL_SCANCODE_1                  = 30,
  SDL_SCANCODE_2                  = 31,
  SDL_SCANCODE_3                  = 32,
  SDL_SCANCODE_4                  = 33,
  SDL_SCANCODE_5                  = 34,
  SDL_SCANCODE_6                  = 35,
  SDL_SCANCODE_7                  = 36,
  SDL_SCANCODE_8                  = 37,
  SDL_SCANCODE_9                  = 38,
  SDL_SCANCODE_0                  = 39,

  SDL_SCANCODE_RETURN             = 40,
  SDL_SCANCODE_ESCAPE             = 41,
  SDL_SCANCODE_BACKSPACE          = 42,
  SDL_SCANCODE_TAB                = 43,
  SDL_SCANCODE_SPACE              = 44,

  SDL_SCANCODE_MINUS              = 45,
  SDL_SCANCODE_EQUALS             = 46,
  SDL_SCANCODE_LEFTBRACKET        = 47,
  SDL_SCANCODE_RIGHTBRACKET       = 48,
  SDL_SCANCODE_BACKSLASH          = 49,
  SDL_SCANCODE_NONUSHASH          = 50,
  SDL_SCANCODE_SEMICOLON          = 51,
  SDL_SCANCODE_APOSTROPHE         = 52,
  SDL_SCANCODE_GRAVE              = 53,
  SDL_SCANCODE_COMMA              = 54,
  SDL_SCANCODE_PERIOD             = 55,
  SDL_SCANCODE_SLASH              = 56,

  SDL_SCANCODE_CAPSLOCK           = 57,

  SDL_SCANCODE_F1                 = 58,
  SDL_SCANCODE_F2                 = 59,
  SDL_SCANCODE_F3                 = 60,
  SDL_SCANCODE_F4                 = 61,
  SDL_SCANCODE_F5                 = 62,
  SDL_SCANCODE_F6                 = 63,
  SDL_SCANCODE_F7                 = 64,
  SDL_SCANCODE_F8                 = 65,
  SDL_SCANCODE_F9                 = 66,
  SDL_SCANCODE_F10                = 67,
  SDL_SCANCODE_F11                = 68,
  SDL_SCANCODE_F12                = 69,

  SDL_SCANCODE_PRINTSCREEN        = 70,
  SDL_SCANCODE_SCROLLLOCK         = 71,
  SDL_SCANCODE_PAUSE              = 72,
  SDL_SCANCODE_INSERT             = 73,
  SDL_SCANCODE_HOME               = 74,
  SDL_SCANCODE_PAGEUP             = 75,
  SDL_SCANCODE_DELETE             = 76,
  SDL_SCANCODE_END                = 77,
  SDL_SCANCODE_PAGEDOWN           = 78,
  SDL_SCANCODE_RIGHT              = 79,
  SDL_SCANCODE_LEFT               = 80,
  SDL_SCANCODE_DOWN               = 81,
  SDL_SCANCODE_UP                 = 82,

  SDL_SCANCODE_NUMLOCKCLEAR       = 83,
  SDL_SCANCODE_KP_DIVIDE          = 84,
  SDL_SCANCODE_KP_MULTIPLY        = 85,
  SDL_SCANCODE_KP_MINUS           = 86,
  SDL_SCANCODE_KP_PLUS            = 87,
  SDL_SCANCODE_KP_ENTER           = 88,
  SDL_SCANCODE_KP_1               = 89,
  SDL_SCANCODE_KP_2               = 90,
  SDL_SCANCODE_KP_3               = 91,
  SDL_SCANCODE_KP_4               = 92,
  SDL_SCANCODE_KP_5               = 93,
  SDL_SCANCODE_KP_6               = 94,
  SDL_SCANCODE_KP_7               = 95,
  SDL_SCANCODE_KP_8               = 96,
  SDL_SCANCODE_KP_9               = 97,
  SDL_SCANCODE_KP_0               = 98,
  SDL_SCANCODE_KP_PERIOD          = 99,

  SDL_SCANCODE_NONUSBACKSLASH     = 100,
  SDL_SCANCODE_APPLICATION        = 101,
  SDL_SCANCODE_POWER              = 102,
  SDL_SCANCODE_KP_EQUALS          = 103,
  SDL_SCANCODE_F13                = 104,
  SDL_SCANCODE_F14                = 105,
  SDL_SCANCODE_F15                = 106,
  SDL_SCANCODE_F16                = 107,
  SDL_SCANCODE_F17                = 108,
  SDL_SCANCODE_F18                = 109,
  SDL_SCANCODE_F19                = 110,
  SDL_SCANCODE_F20                = 111,
  SDL_SCANCODE_F21                = 112,
  SDL_SCANCODE_F22                = 113,
  SDL_SCANCODE_F23                = 114,
  SDL_SCANCODE_F24                = 115,
  SDL_SCANCODE_EXECUTE            = 116,
  SDL_SCANCODE_HELP               = 117,
  SDL_SCANCODE_MENU               = 118,
  SDL_SCANCODE_SELECT             = 119,
  SDL_SCANCODE_STOP               = 120,
  SDL_SCANCODE_AGAIN              = 121,
  SDL_SCANCODE_UNDO               = 122,
  SDL_SCANCODE_CUT                = 123,
  SDL_SCANCODE_COPY               = 124,
  SDL_SCANCODE_PASTE              = 125,
  SDL_SCANCODE_FIND               = 126,
  SDL_SCANCODE_MUTE               = 127,
  SDL_SCANCODE_VOLUMEUP           = 128,
  SDL_SCANCODE_VOLUMEDOWN         = 129,
  SDL_SCANCODE_LOCKINGCAPSLOCK    = 130,
  SDL_SCANCODE_LOCKINGNUMLOCK     = 131,
  SDL_SCANCODE_LOCKINGSCROLLLOCK  = 132,
  SDL_SCANCODE_KP_COMMA           = 133,
  SDL_SCANCODE_KP_EQUALSAS400     = 134,

  SDL_SCANCODE_INTERNATIONAL1     = 135,
  SDL_SCANCODE_INTERNATIONAL2     = 136,
  SDL_SCANCODE_INTERNATIONAL3     = 137,
  SDL_SCANCODE_INTERNATIONAL4     = 138,
  SDL_SCANCODE_INTERNATIONAL5     = 139,
  SDL_SCANCODE_INTERNATIONAL6     = 140,
  SDL_SCANCODE_INTERNATIONAL7     = 141,
  SDL_SCANCODE_INTERNATIONAL8     = 142,
  SDL_SCANCODE_INTERNATIONAL9     = 143,
  SDL_SCANCODE_LANG1              = 144,
  SDL_SCANCODE_LANG2              = 145,
  SDL_SCANCODE_LANG3              = 146,
  SDL_SCANCODE_LANG4              = 147,
  SDL_SCANCODE_LANG5              = 148,
  SDL_SCANCODE_LANG6              = 149,
  SDL_SCANCODE_LANG7              = 150,
  SDL_SCANCODE_LANG8              = 151,
  SDL_SCANCODE_LANG9              = 152,

  SDL_SCANCODE_ALTERASE           = 153,
  SDL_SCANCODE_SYSREQ             = 154,
  SDL_SCANCODE_CANCEL             = 155,
  SDL_SCANCODE_CLEAR              = 156,
  SDL_SCANCODE_PRIOR              = 157,
  SDL_SCANCODE_RETURN2            = 158,
  SDL_SCANCODE_SEPARATOR          = 159,
  SDL_SCANCODE_OUT                = 160,
  SDL_SCANCODE_OPER               = 161,
  SDL_SCANCODE_CLEARAGAIN         = 162,
  SDL_SCANCODE_CRSEL              = 163,
  SDL_SCANCODE_EXSEL              = 164,

  SDL_SCANCODE_KP_00              = 176,
  SDL_SCANCODE_KP_000             = 177,
  SDL_SCANCODE_THOUSANDSSEPARATOR = 178,
  SDL_SCANCODE_DECIMALSEPARATOR   = 179,
  SDL_SCANCODE_CURRENCYUNIT       = 180,
  SDL_SCANCODE_CURRENCYSUBUNIT    = 181,
  SDL_SCANCODE_KP_LEFTPAREN       = 182,
  SDL_SCANCODE_KP_RIGHTPAREN      = 183,
  SDL_SCANCODE_KP_LEFTBRACE       = 184,
  SDL_SCANCODE_KP_RIGHTBRACE      = 185,
  SDL_SCANCODE_KP_TAB             = 186,
  SDL_SCANCODE_KP_BACKSPACE       = 187,
  SDL_SCANCODE_KP_A               = 188,
  SDL_SCANCODE_KP_B               = 189,
  SDL_SCANCODE_KP_C               = 190,
  SDL_SCANCODE_KP_D               = 191,
  SDL_SCANCODE_KP_E               = 192,
  SDL_SCANCODE_KP_F               = 193,
  SDL_SCANCODE_KP_XOR             = 194,
  SDL_SCANCODE_KP_POWER           = 195,
  SDL_SCANCODE_KP_PERCENT         = 196,
  SDL_SCANCODE_KP_LESS            = 197,
  SDL_SCANCODE_KP_GREATER         = 198,
  SDL_SCANCODE_KP_AMPERSAND       = 199,
  SDL_SCANCODE_KP_DBLAMPERSAND    = 200,
  SDL_SCANCODE_KP_VERTICALBAR     = 201,
  SDL_SCANCODE_KP_DBLVERTICALBAR  = 202,
  SDL_SCANCODE_KP_COLON           = 203,
  SDL_SCANCODE_KP_HASH            = 204,
  SDL_SCANCODE_KP_SPACE           = 205,
  SDL_SCANCODE_KP_AT              = 206,
  SDL_SCANCODE_KP_EXCLAM          = 207,
  SDL_SCANCODE_KP_MEMSTORE        = 208,
  SDL_SCANCODE_KP_MEMRECALL       = 209,
  SDL_SCANCODE_KP_MEMCLEAR        = 210,
  SDL_SCANCODE_KP_MEMADD          = 211,
  SDL_SCANCODE_KP_MEMSUBTRACT     = 212,
  SDL_SCANCODE_KP_MEMMULTIPLY     = 213,
  SDL_SCANCODE_KP_MEMDIVIDE       = 214,
  SDL_SCANCODE_KP_PLUSMINUS       = 215,
  SDL_SCANCODE_KP_CLEAR           = 216,
  SDL_SCANCODE_KP_CLEARENTRY      = 217,
  SDL_SCANCODE_KP_BINARY          = 218,
  SDL_SCANCODE_KP_OCTAL           = 219,
  SDL_SCANCODE_KP_DECIMAL         = 220,
  SDL_SCANCODE_KP_HEXADECIMAL     = 221,

  SDL_SCANCODE_LCTRL              = 224,
  SDL_SCANCODE_LSHIFT             = 225,
  SDL_SCANCODE_LALT               = 226,
  SDL_SCANCODE_LGUI               = 227,
  SDL_SCANCODE_RCTRL              = 228,
  SDL_SCANCODE_RSHIFT             = 229,
  SDL_SCANCODE_RALT               = 230,
  SDL_SCANCODE_RGUI               = 231,

  SDL_SCANCODE_MODE               = 257,

  SDL_SCANCODE_AUDIONEXT          = 258,
  SDL_SCANCODE_AUDIOPREV          = 259,
  SDL_SCANCODE_AUDIOSTOP          = 260,
  SDL_SCANCODE_AUDIOPLAY          = 261,
  SDL_SCANCODE_AUDIOMUTE          = 262,
  SDL_SCANCODE_MEDIASELECT        = 263,
  SDL_SCANCODE_WWW                = 264,
  SDL_SCANCODE_MAIL               = 265,
  SDL_SCANCODE_CALCULATOR         = 266,
  SDL_SCANCODE_COMPUTER           = 267,
  SDL_SCANCODE_AC_SEARCH          = 268,
  SDL_SCANCODE_AC_HOME            = 269,
  SDL_SCANCODE_AC_BACK            = 270,
  SDL_SCANCODE_AC_FORWARD         = 271,
  SDL_SCANCODE_AC_STOP            = 272,
  SDL_SCANCODE_AC_REFRESH         = 273,
  SDL_SCANCODE_AC_BOOKMARKS       = 274,

  SDL_SCANCODE_BRIGHTNESSDOWN     = 275,
  SDL_SCANCODE_BRIGHTNESSUP       = 276,
  SDL_SCANCODE_DISPLAYSWITCH      = 277,
  SDL_SCANCODE_KBDILLUMTOGGLE     = 278,
  SDL_SCANCODE_KBDILLUMDOWN       = 279,
  SDL_SCANCODE_KBDILLUMUP         = 280,
  SDL_SCANCODE_EJECT              = 281,
  SDL_SCANCODE_SLEEP              = 282,

  SDL_SCANCODE_APP1               = 283,
  SDL_SCANCODE_APP2               = 284,

  SDL_NUM_SCANCODES               = 512
} SDL_Scancode;

/* SDL_keycode.h */

typedef Sint32 SDL_Keycode;

enum {
  SDLK_UNKNOWN            = 0,

  SDLK_RETURN             = '\r',
  SDLK_ESCAPE             = '\033',
  SDLK_BACKSPACE          = '\b',
  SDLK_TAB                = '\t',
  SDLK_SPACE              = ' ',
  SDLK_EXCLAIM            = '!',
  SDLK_QUOTEDBL           = '"',
  SDLK_HASH               = '#',
  SDLK_PERCENT            = '%',
  SDLK_DOLLAR             = '$',
  SDLK_AMPERSAND          = '&',
  SDLK_QUOTE              = '\'',
  SDLK_LEFTPAREN          = '(',
  SDLK_RIGHTPAREN         = ')',
  SDLK_ASTERISK           = '*',
  SDLK_PLUS               = '+',
  SDLK_COMMA              = ',',
  SDLK_MINUS              = '-',
  SDLK_PERIOD             = '.',
  SDLK_SLASH              = '/',
  SDLK_0                  = '0',
  SDLK_1                  = '1',
  SDLK_2                  = '2',
  SDLK_3                  = '3',
  SDLK_4                  = '4',
  SDLK_5                  = '5',
  SDLK_6                  = '6',
  SDLK_7                  = '7',
  SDLK_8                  = '8',
  SDLK_9                  = '9',
  SDLK_COLON              = ':',
  SDLK_SEMICOLON          = ';',
  SDLK_LESS               = '<',
  SDLK_EQUALS             = '=',
  SDLK_GREATER            = '>',
  SDLK_QUESTION           = '?',
  SDLK_AT                 = '@',

  SDLK_LEFTBRACKET        = '[',
  SDLK_BACKSLASH          = '\\',
  SDLK_RIGHTBRACKET       = ']',
  SDLK_CARET              = '^',
  SDLK_UNDERSCORE         = '_',
  SDLK_BACKQUOTE          = '`',
  SDLK_a                  = 'a',
  SDLK_b                  = 'b',
  SDLK_c                  = 'c',
  SDLK_d                  = 'd',
  SDLK_e                  = 'e',
  SDLK_f                  = 'f',
  SDLK_g                  = 'g',
  SDLK_h                  = 'h',
  SDLK_i                  = 'i',
  SDLK_j                  = 'j',
  SDLK_k                  = 'k',
  SDLK_l                  = 'l',
  SDLK_m                  = 'm',
  SDLK_n                  = 'n',
  SDLK_o                  = 'o',
  SDLK_p                  = 'p',
  SDLK_q                  = 'q',
  SDLK_r                  = 'r',
  SDLK_s                  = 's',
  SDLK_t                  = 't',
  SDLK_u                  = 'u',
  SDLK_v                  = 'v',
  SDLK_w                  = 'w',
  SDLK_x                  = 'x',
  SDLK_y                  = 'y',
  SDLK_z                  = 'z',

  SDLK_CAPSLOCK           = SDL_SCANCODE_CAPSLOCK | (1<<30),

  SDLK_F1                 = SDL_SCANCODE_F1 | (1<<30),
  SDLK_F2                 = SDL_SCANCODE_F2 | (1<<30),
  SDLK_F3                 = SDL_SCANCODE_F3 | (1<<30),
  SDLK_F4                 = SDL_SCANCODE_F4 | (1<<30),
  SDLK_F5                 = SDL_SCANCODE_F5 | (1<<30),
  SDLK_F6                 = SDL_SCANCODE_F6 | (1<<30),
  SDLK_F7                 = SDL_SCANCODE_F7 | (1<<30),
  SDLK_F8                 = SDL_SCANCODE_F8 | (1<<30),
  SDLK_F9                 = SDL_SCANCODE_F9 | (1<<30),
  SDLK_F10                = SDL_SCANCODE_F10 | (1<<30),
  SDLK_F11                = SDL_SCANCODE_F11 | (1<<30),
  SDLK_F12                = SDL_SCANCODE_F12 | (1<<30),

  SDLK_PRINTSCREEN        = SDL_SCANCODE_PRINTSCREEN | (1<<30),
  SDLK_SCROLLLOCK         = SDL_SCANCODE_SCROLLLOCK | (1<<30),
  SDLK_PAUSE              = SDL_SCANCODE_PAUSE | (1<<30),
  SDLK_INSERT             = SDL_SCANCODE_INSERT | (1<<30),
  SDLK_HOME               = SDL_SCANCODE_HOME | (1<<30),
  SDLK_PAGEUP             = SDL_SCANCODE_PAGEUP | (1<<30),
  SDLK_DELETE             = '\177',
  SDLK_END                = SDL_SCANCODE_END | (1<<30),
  SDLK_PAGEDOWN           = SDL_SCANCODE_PAGEDOWN | (1<<30),
  SDLK_RIGHT              = SDL_SCANCODE_RIGHT | (1<<30),
  SDLK_LEFT               = SDL_SCANCODE_LEFT | (1<<30),
  SDLK_DOWN               = SDL_SCANCODE_DOWN | (1<<30),
  SDLK_UP                 = SDL_SCANCODE_UP | (1<<30),

  SDLK_NUMLOCKCLEAR       = SDL_SCANCODE_NUMLOCKCLEAR | (1<<30),
  SDLK_KP_DIVIDE          = SDL_SCANCODE_KP_DIVIDE | (1<<30),
  SDLK_KP_MULTIPLY        = SDL_SCANCODE_KP_MULTIPLY | (1<<30),
  SDLK_KP_MINUS           = SDL_SCANCODE_KP_MINUS | (1<<30),
  SDLK_KP_PLUS            = SDL_SCANCODE_KP_PLUS | (1<<30),
  SDLK_KP_ENTER           = SDL_SCANCODE_KP_ENTER | (1<<30),
  SDLK_KP_1               = SDL_SCANCODE_KP_1 | (1<<30),
  SDLK_KP_2               = SDL_SCANCODE_KP_2 | (1<<30),
  SDLK_KP_3               = SDL_SCANCODE_KP_3 | (1<<30),
  SDLK_KP_4               = SDL_SCANCODE_KP_4 | (1<<30),
  SDLK_KP_5               = SDL_SCANCODE_KP_5 | (1<<30),
  SDLK_KP_6               = SDL_SCANCODE_KP_6 | (1<<30),
  SDLK_KP_7               = SDL_SCANCODE_KP_7 | (1<<30),
  SDLK_KP_8               = SDL_SCANCODE_KP_8 | (1<<30),
  SDLK_KP_9               = SDL_SCANCODE_KP_9 | (1<<30),
  SDLK_KP_0               = SDL_SCANCODE_KP_0 | (1<<30),
  SDLK_KP_PERIOD          = SDL_SCANCODE_KP_PERIOD | (1<<30),

  SDLK_APPLICATION        = SDL_SCANCODE_APPLICATION | (1<<30),
  SDLK_POWER              = SDL_SCANCODE_POWER | (1<<30),
  SDLK_KP_EQUALS          = SDL_SCANCODE_KP_EQUALS | (1<<30),
  SDLK_F13                = SDL_SCANCODE_F13 | (1<<30),
  SDLK_F14                = SDL_SCANCODE_F14 | (1<<30),
  SDLK_F15                = SDL_SCANCODE_F15 | (1<<30),
  SDLK_F16                = SDL_SCANCODE_F16 | (1<<30),
  SDLK_F17                = SDL_SCANCODE_F17 | (1<<30),
  SDLK_F18                = SDL_SCANCODE_F18 | (1<<30),
  SDLK_F19                = SDL_SCANCODE_F19 | (1<<30),
  SDLK_F20                = SDL_SCANCODE_F20 | (1<<30),
  SDLK_F21                = SDL_SCANCODE_F21 | (1<<30),
  SDLK_F22                = SDL_SCANCODE_F22 | (1<<30),
  SDLK_F23                = SDL_SCANCODE_F23 | (1<<30),
  SDLK_F24                = SDL_SCANCODE_F24 | (1<<30),
  SDLK_EXECUTE            = SDL_SCANCODE_EXECUTE | (1<<30),
  SDLK_HELP               = SDL_SCANCODE_HELP | (1<<30),
  SDLK_MENU               = SDL_SCANCODE_MENU | (1<<30),
  SDLK_SELECT             = SDL_SCANCODE_SELECT | (1<<30),
  SDLK_STOP               = SDL_SCANCODE_STOP | (1<<30),
  SDLK_AGAIN              = SDL_SCANCODE_AGAIN | (1<<30),
  SDLK_UNDO               = SDL_SCANCODE_UNDO | (1<<30),
  SDLK_CUT                = SDL_SCANCODE_CUT | (1<<30),
  SDLK_COPY               = SDL_SCANCODE_COPY | (1<<30),
  SDLK_PASTE              = SDL_SCANCODE_PASTE | (1<<30),
  SDLK_FIND               = SDL_SCANCODE_FIND | (1<<30),
  SDLK_MUTE               = SDL_SCANCODE_MUTE | (1<<30),
  SDLK_VOLUMEUP           = SDL_SCANCODE_VOLUMEUP | (1<<30),
  SDLK_VOLUMEDOWN         = SDL_SCANCODE_VOLUMEDOWN | (1<<30),
  SDLK_KP_COMMA           = SDL_SCANCODE_KP_COMMA | (1<<30),
  SDLK_KP_EQUALSAS400     = SDL_SCANCODE_KP_EQUALSAS400 | (1<<30),

  SDLK_ALTERASE           = SDL_SCANCODE_ALTERASE | (1<<30),
  SDLK_SYSREQ             = SDL_SCANCODE_SYSREQ | (1<<30),
  SDLK_CANCEL             = SDL_SCANCODE_CANCEL | (1<<30),
  SDLK_CLEAR              = SDL_SCANCODE_CLEAR | (1<<30),
  SDLK_PRIOR              = SDL_SCANCODE_PRIOR | (1<<30),
  SDLK_RETURN2            = SDL_SCANCODE_RETURN2 | (1<<30),
  SDLK_SEPARATOR          = SDL_SCANCODE_SEPARATOR | (1<<30),
  SDLK_OUT                = SDL_SCANCODE_OUT | (1<<30),
  SDLK_OPER               = SDL_SCANCODE_OPER | (1<<30),
  SDLK_CLEARAGAIN         = SDL_SCANCODE_CLEARAGAIN | (1<<30),
  SDLK_CRSEL              = SDL_SCANCODE_CRSEL | (1<<30),
  SDLK_EXSEL              = SDL_SCANCODE_EXSEL | (1<<30),

  SDLK_KP_00              = SDL_SCANCODE_KP_00 | (1<<30),
  SDLK_KP_000             = SDL_SCANCODE_KP_000 | (1<<30),
  SDLK_THOUSANDSSEPARATOR = SDL_SCANCODE_THOUSANDSSEPARATOR | (1<<30),
  SDLK_DECIMALSEPARATOR   = SDL_SCANCODE_DECIMALSEPARATOR | (1<<30),
  SDLK_CURRENCYUNIT       = SDL_SCANCODE_CURRENCYUNIT | (1<<30),
  SDLK_CURRENCYSUBUNIT    = SDL_SCANCODE_CURRENCYSUBUNIT | (1<<30),
  SDLK_KP_LEFTPAREN       = SDL_SCANCODE_KP_LEFTPAREN | (1<<30),
  SDLK_KP_RIGHTPAREN      = SDL_SCANCODE_KP_RIGHTPAREN | (1<<30),
  SDLK_KP_LEFTBRACE       = SDL_SCANCODE_KP_LEFTBRACE | (1<<30),
  SDLK_KP_RIGHTBRACE      = SDL_SCANCODE_KP_RIGHTBRACE | (1<<30),
  SDLK_KP_TAB             = SDL_SCANCODE_KP_TAB | (1<<30),
  SDLK_KP_BACKSPACE       = SDL_SCANCODE_KP_BACKSPACE | (1<<30),
  SDLK_KP_A               = SDL_SCANCODE_KP_A | (1<<30),
  SDLK_KP_B               = SDL_SCANCODE_KP_B | (1<<30),
  SDLK_KP_C               = SDL_SCANCODE_KP_C | (1<<30),
  SDLK_KP_D               = SDL_SCANCODE_KP_D | (1<<30),
  SDLK_KP_E               = SDL_SCANCODE_KP_E | (1<<30),
  SDLK_KP_F               = SDL_SCANCODE_KP_F | (1<<30),
  SDLK_KP_XOR             = SDL_SCANCODE_KP_XOR | (1<<30),
  SDLK_KP_POWER           = SDL_SCANCODE_KP_POWER | (1<<30),
  SDLK_KP_PERCENT         = SDL_SCANCODE_KP_PERCENT | (1<<30),
  SDLK_KP_LESS            = SDL_SCANCODE_KP_LESS | (1<<30),
  SDLK_KP_GREATER         = SDL_SCANCODE_KP_GREATER | (1<<30),
  SDLK_KP_AMPERSAND       = SDL_SCANCODE_KP_AMPERSAND | (1<<30),
  SDLK_KP_DBLAMPERSAND    = SDL_SCANCODE_KP_DBLAMPERSAND | (1<<30),
  SDLK_KP_VERTICALBAR     = SDL_SCANCODE_KP_VERTICALBAR | (1<<30),
  SDLK_KP_DBLVERTICALBAR  = SDL_SCANCODE_KP_DBLVERTICALBAR | (1<<30),
  SDLK_KP_COLON           = SDL_SCANCODE_KP_COLON | (1<<30),
  SDLK_KP_HASH            = SDL_SCANCODE_KP_HASH | (1<<30),
  SDLK_KP_SPACE           = SDL_SCANCODE_KP_SPACE | (1<<30),
  SDLK_KP_AT              = SDL_SCANCODE_KP_AT | (1<<30),
  SDLK_KP_EXCLAM          = SDL_SCANCODE_KP_EXCLAM | (1<<30),
  SDLK_KP_MEMSTORE        = SDL_SCANCODE_KP_MEMSTORE | (1<<30),
  SDLK_KP_MEMRECALL       = SDL_SCANCODE_KP_MEMRECALL | (1<<30),
  SDLK_KP_MEMCLEAR        = SDL_SCANCODE_KP_MEMCLEAR | (1<<30),
  SDLK_KP_MEMADD          = SDL_SCANCODE_KP_MEMADD | (1<<30),
  SDLK_KP_MEMSUBTRACT     = SDL_SCANCODE_KP_MEMSUBTRACT | (1<<30),
  SDLK_KP_MEMMULTIPLY     = SDL_SCANCODE_KP_MEMMULTIPLY | (1<<30),
  SDLK_KP_MEMDIVIDE       = SDL_SCANCODE_KP_MEMDIVIDE | (1<<30),
  SDLK_KP_PLUSMINUS       = SDL_SCANCODE_KP_PLUSMINUS | (1<<30),
  SDLK_KP_CLEAR           = SDL_SCANCODE_KP_CLEAR | (1<<30),
  SDLK_KP_CLEARENTRY      = SDL_SCANCODE_KP_CLEARENTRY | (1<<30),
  SDLK_KP_BINARY          = SDL_SCANCODE_KP_BINARY | (1<<30),
  SDLK_KP_OCTAL           = SDL_SCANCODE_KP_OCTAL | (1<<30),
  SDLK_KP_DECIMAL         = SDL_SCANCODE_KP_DECIMAL | (1<<30),
  SDLK_KP_HEXADECIMAL     = SDL_SCANCODE_KP_HEXADECIMAL | (1<<30),

  SDLK_LCTRL              = SDL_SCANCODE_LCTRL | (1<<30),
  SDLK_LSHIFT             = SDL_SCANCODE_LSHIFT | (1<<30),
  SDLK_LALT               = SDL_SCANCODE_LALT | (1<<30),
  SDLK_LGUI               = SDL_SCANCODE_LGUI | (1<<30),
  SDLK_RCTRL              = SDL_SCANCODE_RCTRL | (1<<30),
  SDLK_RSHIFT             = SDL_SCANCODE_RSHIFT | (1<<30),
  SDLK_RALT               = SDL_SCANCODE_RALT | (1<<30),
  SDLK_RGUI               = SDL_SCANCODE_RGUI | (1<<30),

  SDLK_MODE               = SDL_SCANCODE_MODE | (1<<30),

  SDLK_AUDIONEXT          = SDL_SCANCODE_AUDIONEXT | (1<<30),
  SDLK_AUDIOPREV          = SDL_SCANCODE_AUDIOPREV | (1<<30),
  SDLK_AUDIOSTOP          = SDL_SCANCODE_AUDIOSTOP | (1<<30),
  SDLK_AUDIOPLAY          = SDL_SCANCODE_AUDIOPLAY | (1<<30),
  SDLK_AUDIOMUTE          = SDL_SCANCODE_AUDIOMUTE | (1<<30),
  SDLK_MEDIASELECT        = SDL_SCANCODE_MEDIASELECT | (1<<30),
  SDLK_WWW                = SDL_SCANCODE_WWW | (1<<30),
  SDLK_MAIL               = SDL_SCANCODE_MAIL | (1<<30),
  SDLK_CALCULATOR         = SDL_SCANCODE_CALCULATOR | (1<<30),
  SDLK_COMPUTER           = SDL_SCANCODE_COMPUTER | (1<<30),
  SDLK_AC_SEARCH          = SDL_SCANCODE_AC_SEARCH | (1<<30),
  SDLK_AC_HOME            = SDL_SCANCODE_AC_HOME | (1<<30),
  SDLK_AC_BACK            = SDL_SCANCODE_AC_BACK | (1<<30),
  SDLK_AC_FORWARD         = SDL_SCANCODE_AC_FORWARD | (1<<30),
  SDLK_AC_STOP            = SDL_SCANCODE_AC_STOP | (1<<30),
  SDLK_AC_REFRESH         = SDL_SCANCODE_AC_REFRESH | (1<<30),
  SDLK_AC_BOOKMARKS       = SDL_SCANCODE_AC_BOOKMARKS | (1<<30),

  SDLK_BRIGHTNESSDOWN     = SDL_SCANCODE_BRIGHTNESSDOWN | (1<<30),
  SDLK_BRIGHTNESSUP       = SDL_SCANCODE_BRIGHTNESSUP | (1<<30),
  SDLK_DISPLAYSWITCH      = SDL_SCANCODE_DISPLAYSWITCH | (1<<30),
  SDLK_KBDILLUMTOGGLE     = SDL_SCANCODE_KBDILLUMTOGGLE | (1<<30),
  SDLK_KBDILLUMDOWN       = SDL_SCANCODE_KBDILLUMDOWN | (1<<30),
  SDLK_KBDILLUMUP         = SDL_SCANCODE_KBDILLUMUP | (1<<30),
  SDLK_EJECT              = SDL_SCANCODE_EJECT | (1<<30),
  SDLK_SLEEP              = SDL_SCANCODE_SLEEP | (1<<30)
};

typedef enum {
  KMOD_NONE     = 0x0000,
  KMOD_LSHIFT   = 0x0001,
  KMOD_RSHIFT   = 0x0002,
  KMOD_LCTRL    = 0x0040,
  KMOD_RCTRL    = 0x0080,
  KMOD_LALT     = 0x0100,
  KMOD_RALT     = 0x0200,
  KMOD_LGUI     = 0x0400,
  KMOD_RGUI     = 0x0800,
  KMOD_NUM      = 0x1000,
  KMOD_CAPS     = 0x2000,
  KMOD_MODE     = 0x4000,
  KMOD_RESERVED = 0x8000
} SDL_Keymod;

static const uint32_t KMOD_CTRL  = (KMOD_LCTRL|KMOD_RCTRL);
static const uint32_t KMOD_SHIFT = (KMOD_LSHIFT|KMOD_RSHIFT);
static const uint32_t KMOD_ALT   = (KMOD_LALT|KMOD_RALT);
static const uint32_t KMOD_GUI   = (KMOD_LGUI|KMOD_RGUI);

SDL_Keymod SDL_GetModState(void);

/* SDL_keyboard.h */

typedef struct SDL_Keysym {
  SDL_Scancode scancode;      /**< SDL physical key code - see ::SDL_Scancode for details */
  SDL_Keycode sym;            /**< SDL virtual key code - see ::SDL_Keycode for details */
  Uint16 mod;                 /**< current key modifiers */
  Uint32 unused;
} SDL_Keysym;

/* SDL_events.h */

enum {
  SDL_RELEASED = 0,
  SDL_PRESSED = 1
};

typedef enum {
  SDL_FIRSTEVENT     = 0,

  /* Application events */
  SDL_QUIT           = 0x100,
  SDL_APP_TERMINATING,
  SDL_APP_LOWMEMORY,
  SDL_APP_WILLENTERBACKGROUND,
  SDL_APP_DIDENTERBACKGROUND,
  SDL_APP_WILLENTERFOREGROUND,
  SDL_APP_DIDENTERFOREGROUND,

  /* Window events */
  SDL_WINDOWEVENT    = 0x200,
  SDL_SYSWMEVENT,

  /* Keyboard events */
  SDL_KEYDOWN        = 0x300,
  SDL_KEYUP,
  SDL_TEXTEDITING,
  SDL_TEXTINPUT,

  /* Mouse events */
  SDL_MOUSEMOTION    = 0x400,
  SDL_MOUSEBUTTONDOWN,
  SDL_MOUSEBUTTONUP,
  SDL_MOUSEWHEEL,

  /* Joystick events */
  SDL_JOYAXISMOTION  = 0x600,
  SDL_JOYBALLMOTION,
  SDL_JOYHATMOTION,
  SDL_JOYBUTTONDOWN,
  SDL_JOYBUTTONUP,
  SDL_JOYDEVICEADDED,
  SDL_JOYDEVICEREMOVED,

  /* Game controller events */
  SDL_CONTROLLERAXISMOTION  = 0x650,
  SDL_CONTROLLERBUTTONDOWN,
  SDL_CONTROLLERBUTTONUP,
  SDL_CONTROLLERDEVICEADDED,
  SDL_CONTROLLERDEVICEREMOVED,
  SDL_CONTROLLERDEVICEREMAPPED,

  /* Touch events */
  SDL_FINGERDOWN      = 0x700,
  SDL_FINGERUP,
  SDL_FINGERMOTION,

  /* Gesture events */
  SDL_DOLLARGESTURE   = 0x800,
  SDL_DOLLARRECORD,
  SDL_MULTIGESTURE,

  /* Clipboard events */
  SDL_CLIPBOARDUPDATE = 0x900,

  /* Drag and drop events */
  SDL_DROPFILE        = 0x1000,

  /* Render events */
  SDL_RENDER_TARGETS_RESET = 0x2000,

  /* User events */
  SDL_USEREVENT    = 0x8000,

  SDL_LASTEVENT    = 0xFFFF
} SDL_EventType;

typedef struct SDL_CommonEvent {
  Uint32 type;
  Uint32 timestamp;
} SDL_CommonEvent;

typedef struct SDL_WindowEvent {
  Uint32 type;        /**< ::SDL_WINDOWEVENT */
  Uint32 timestamp;
  Uint32 windowID;    /**< The associated window */
  Uint8 event;        /**< ::SDL_WindowEventID */
  Uint8 padding1;
  Uint8 padding2;
  Uint8 padding3;
  Sint32 data1;       /**< event dependent data */
  Sint32 data2;       /**< event dependent data */
} SDL_WindowEvent;

typedef struct SDL_KeyboardEvent {
  Uint32 type;        /**< ::SDL_KEYDOWN or ::SDL_KEYUP */
  Uint32 timestamp;
  Uint32 windowID;    /**< The window with keyboard focus, if any */
  Uint8 state;        /**< ::SDL_PRESSED or ::SDL_RELEASED */
  Uint8 repeat;       /**< Non-zero if this is a key repeat */
  Uint8 padding2;
  Uint8 padding3;
  SDL_Keysym keysym;  /**< The key that was pressed or released */
} SDL_KeyboardEvent;

static const int SDL_TEXTEDITINGEVENT_TEXT_SIZE = 32;

typedef struct SDL_TextEditingEvent {
  Uint32 type;                                /**< ::SDL_TEXTEDITING */
  Uint32 timestamp;
  Uint32 windowID;                            /**< The window with keyboard focus, if any */
  char text[SDL_TEXTEDITINGEVENT_TEXT_SIZE];  /**< The editing text */
  Sint32 start;                               /**< The start cursor of selected editing text */
  Sint32 length;                              /**< The length of selected editing text */
} SDL_TextEditingEvent;

static const int SDL_TEXTINPUTEVENT_TEXT_SIZE = 32;

typedef struct SDL_TextInputEvent {
  Uint32 type;                              /**< ::SDL_TEXTINPUT */
  Uint32 timestamp;
  Uint32 windowID;                          /**< The window with keyboard focus, if any */
  char text[SDL_TEXTINPUTEVENT_TEXT_SIZE];  /**< The input text */
} SDL_TextInputEvent;

typedef struct SDL_MouseMotionEvent {
  Uint32 type;        /**< ::SDL_MOUSEMOTION */
  Uint32 timestamp;
  Uint32 windowID;    /**< The window with mouse focus, if any */
  Uint32 which;       /**< The mouse instance id, or SDL_TOUCH_MOUSEID */
  Uint32 state;       /**< The current button state */
  Sint32 x;           /**< X coordinate, relative to window */
  Sint32 y;           /**< Y coordinate, relative to window */
  Sint32 xrel;        /**< The relative motion in the X direction */
  Sint32 yrel;        /**< The relative motion in the Y direction */
} SDL_MouseMotionEvent;

typedef struct SDL_MouseButtonEvent {
  Uint32 type;        /**< ::SDL_MOUSEBUTTONDOWN or ::SDL_MOUSEBUTTONUP */
  Uint32 timestamp;
  Uint32 windowID;    /**< The window with mouse focus, if any */
  Uint32 which;       /**< The mouse instance id, or SDL_TOUCH_MOUSEID */
  Uint8 button;       /**< The mouse button index */
  Uint8 state;        /**< ::SDL_PRESSED or ::SDL_RELEASED */
  Uint8 clicks;       /**< 1 for single-click, 2 for double-click, etc. */
  Uint8 padding1;
  Sint32 x;           /**< X coordinate, relative to window */
  Sint32 y;           /**< Y coordinate, relative to window */
} SDL_MouseButtonEvent;

typedef struct SDL_MouseWheelEvent {
  Uint32 type;        /**< ::SDL_MOUSEWHEEL */
  Uint32 timestamp;
  Uint32 windowID;    /**< The window with mouse focus, if any */
  Uint32 which;       /**< The mouse instance id, or SDL_TOUCH_MOUSEID */
  Sint32 x;           /**< The amount scrolled horizontally, positive to the right and negative to the left */
  Sint32 y;           /**< The amount scrolled vertically, positive away from the user and negative toward the user */
} SDL_MouseWheelEvent;

typedef Sint32 SDL_JoystickID;

typedef struct SDL_JoyAxisEvent {
  Uint32 type;        /**< ::SDL_JOYAXISMOTION */
  Uint32 timestamp;
  SDL_JoystickID which; /**< The joystick instance id */
  Uint8 axis;         /**< The joystick axis index */
  Uint8 padding1;
  Uint8 padding2;
  Uint8 padding3;
  Sint16 value;       /**< The axis value (range: -32768 to 32767) */
  Uint16 padding4;
} SDL_JoyAxisEvent;

typedef struct SDL_JoyBallEvent {
  Uint32 type;        /**< ::SDL_JOYBALLMOTION */
  Uint32 timestamp;
  SDL_JoystickID which; /**< The joystick instance id */
  Uint8 ball;         /**< The joystick trackball index */
  Uint8 padding1;
  Uint8 padding2;
  Uint8 padding3;
  Sint16 xrel;        /**< The relative motion in the X direction */
  Sint16 yrel;        /**< The relative motion in the Y direction */
} SDL_JoyBallEvent;

typedef struct SDL_JoyHatEvent {
  Uint32 type;        /**< ::SDL_JOYHATMOTION */
  Uint32 timestamp;
  SDL_JoystickID which; /**< The joystick instance id */
  Uint8 hat;          /**< The joystick hat index */
  Uint8 value;        /**< The hat position value.
                       *   \sa ::SDL_HAT_LEFTUP ::SDL_HAT_UP ::SDL_HAT_RIGHTUP
                       *   \sa ::SDL_HAT_LEFT ::SDL_HAT_CENTERED ::SDL_HAT_RIGHT
                       *   \sa ::SDL_HAT_LEFTDOWN ::SDL_HAT_DOWN ::SDL_HAT_RIGHTDOWN
                       *
                       *   Note that zero means the POV is centered.
                       */
  Uint8 padding1;
  Uint8 padding2;
} SDL_JoyHatEvent;

typedef struct SDL_JoyButtonEvent {
  Uint32 type;        /**< ::SDL_JOYBUTTONDOWN or ::SDL_JOYBUTTONUP */
  Uint32 timestamp;
  SDL_JoystickID which; /**< The joystick instance id */
  Uint8 button;       /**< The joystick button index */
  Uint8 state;        /**< ::SDL_PRESSED or ::SDL_RELEASED */
  Uint8 padding1;
  Uint8 padding2;
} SDL_JoyButtonEvent;

typedef struct SDL_JoyDeviceEvent {
  Uint32 type;        /**< ::SDL_JOYDEVICEADDED or ::SDL_JOYDEVICEREMOVED */
  Uint32 timestamp;
  Sint32 which;       /**< The joystick device index for the ADDED event, instance id for the REMOVED event */
} SDL_JoyDeviceEvent;

typedef struct SDL_ControllerAxisEvent {
  Uint32 type;        /**< ::SDL_CONTROLLERAXISMOTION */
  Uint32 timestamp;
  SDL_JoystickID which; /**< The joystick instance id */
  Uint8 axis;         /**< The controller axis (SDL_GameControllerAxis) */
  Uint8 padding1;
  Uint8 padding2;
  Uint8 padding3;
  Sint16 value;       /**< The axis value (range: -32768 to 32767) */
  Uint16 padding4;
} SDL_ControllerAxisEvent;

typedef struct SDL_ControllerButtonEvent {
  Uint32 type;        /**< ::SDL_CONTROLLERBUTTONDOWN or ::SDL_CONTROLLERBUTTONUP */
  Uint32 timestamp;
  SDL_JoystickID which; /**< The joystick instance id */
  Uint8 button;       /**< The controller button (SDL_GameControllerButton) */
  Uint8 state;        /**< ::SDL_PRESSED or ::SDL_RELEASED */
  Uint8 padding1;
  Uint8 padding2;
} SDL_ControllerButtonEvent;

typedef struct SDL_ControllerDeviceEvent {
  Uint32 type;        /**< ::SDL_CONTROLLERDEVICEADDED, ::SDL_CONTROLLERDEVICEREMOVED, or ::SDL_CONTROLLERDEVICEREMAPPED */
  Uint32 timestamp;
  Sint32 which;       /**< The joystick device index for the ADDED event, instance id for the REMOVED or REMAPPED event */
} SDL_ControllerDeviceEvent;

typedef Sint64 SDL_TouchID;
typedef Sint64 SDL_FingerID;

typedef struct SDL_TouchFingerEvent {
  Uint32 type;        /**< ::SDL_FINGERMOTION or ::SDL_FINGERDOWN or ::SDL_FINGERUP */
  Uint32 timestamp;
  SDL_TouchID touchId; /**< The touch device id */
  SDL_FingerID fingerId;
  float x;            /**< Normalized in the range 0...1 */
  float y;            /**< Normalized in the range 0...1 */
  float dx;           /**< Normalized in the range 0...1 */
  float dy;           /**< Normalized in the range 0...1 */
  float pressure;     /**< Normalized in the range 0...1 */
} SDL_TouchFingerEvent;

typedef struct SDL_MultiGestureEvent {
  Uint32 type;        /**< ::SDL_MULTIGESTURE */
  Uint32 timestamp;
  SDL_TouchID touchId; /**< The touch device index */
  float dTheta;
  float dDist;
  float x;
  float y;
  Uint16 numFingers;
  Uint16 padding;
} SDL_MultiGestureEvent;

typedef Sint64 SDL_GestureID;

typedef struct SDL_DollarGestureEvent {
  Uint32 type;        /**< ::SDL_DOLLARGESTURE */
  Uint32 timestamp;
  SDL_TouchID touchId; /**< The touch device id */
  SDL_GestureID gestureId;
  Uint32 numFingers;
  float error;
  float x;            /**< Normalized center of gesture */
  float y;            /**< Normalized center of gesture */
} SDL_DollarGestureEvent;

typedef struct SDL_DropEvent {
  Uint32 type;        /**< ::SDL_DROPFILE */
  Uint32 timestamp;
  char *file;         /**< The file name, which should be freed with SDL_free() */
} SDL_DropEvent;

typedef struct SDL_QuitEvent {
  Uint32 type;        /**< ::SDL_QUIT */
  Uint32 timestamp;
} SDL_QuitEvent;

typedef struct SDL_OSEvent {
  Uint32 type;        /**< ::SDL_QUIT */
  Uint32 timestamp;
} SDL_OSEvent;

typedef struct SDL_UserEvent {
    Uint32 type;        /**< ::SDL_USEREVENT through ::SDL_LASTEVENT-1 */
    Uint32 timestamp;
    Uint32 windowID;    /**< The associated window if any */
    Sint32 code;        /**< User defined event code */
    void *data1;        /**< User defined data pointer */
    void *data2;        /**< User defined data pointer */
} SDL_UserEvent;

struct SDL_SysWMmsg;
typedef struct SDL_SysWMmsg SDL_SysWMmsg;

typedef struct SDL_SysWMEvent
{
  Uint32 type;        /**< ::SDL_SYSWMEVENT */
  Uint32 timestamp;
  SDL_SysWMmsg *msg;  /**< driver dependent data, defined in SDL_syswm.h */
} SDL_SysWMEvent;

typedef union SDL_Event {
  Uint32 type;                    /**< Event type, shared with all events */
  SDL_CommonEvent common;         /**< Common event data */
  SDL_WindowEvent window;         /**< Window event data */
  SDL_KeyboardEvent key;          /**< Keyboard event data */
  SDL_TextEditingEvent edit;      /**< Text editing event data */
  SDL_TextInputEvent text;        /**< Text input event data */
  SDL_MouseMotionEvent motion;    /**< Mouse motion event data */
  SDL_MouseButtonEvent button;    /**< Mouse button event data */
  SDL_MouseWheelEvent wheel;      /**< Mouse wheel event data */
  SDL_JoyAxisEvent jaxis;         /**< Joystick axis event data */
  SDL_JoyBallEvent jball;         /**< Joystick ball event data */
  SDL_JoyHatEvent jhat;           /**< Joystick hat event data */
  SDL_JoyButtonEvent jbutton;     /**< Joystick button event data */
  SDL_JoyDeviceEvent jdevice;     /**< Joystick device change event data */
  SDL_ControllerAxisEvent caxis;      /**< Game Controller axis event data */
  SDL_ControllerButtonEvent cbutton;  /**< Game Controller button event data */
  SDL_ControllerDeviceEvent cdevice;  /**< Game Controller device event data */
  SDL_QuitEvent quit;             /**< Quit request event data */
  SDL_UserEvent user;             /**< Custom event data */
  SDL_SysWMEvent syswm;           /**< System dependent window event data */
  SDL_TouchFingerEvent tfinger;   /**< Touch finger event data */
  SDL_MultiGestureEvent mgesture; /**< Gesture event data */
  SDL_DollarGestureEvent dgesture; /**< Gesture event data */
  SDL_DropEvent drop;             /**< Drag and drop event data */

  /* This is necessary for ABI compatibility between Visual C++ and GCC
     Visual C++ will respect the push pack pragma and use 52 bytes for
     this structure, and GCC will use the alignment of the largest datatype
     within the union, which is 8 bytes.

     So... we'll add padding to force the size to be 56 bytes for both.
  */
  Uint8 padding[56];
} SDL_Event;

void SDL_PumpEvents (void);
int SDL_PollEvent (SDL_Event * event);

/* SDL_rect.h */

typedef struct SDL_Point {
  int x;
  int y;
} SDL_Point;

typedef struct SDL_Rect {
  int x, y;
  int w, h;
} SDL_Rect;

/* SDL_surface.h */

struct SDL_Surface;
typedef struct SDL_Surface SDL_Surface;

/* SDL_pixels.h */

enum {
  SDL_ALPHA_OPAQUE = 255,
  SDL_ALPHA_TRANSPARENT = 0
};

/** Pixel type. */
enum {
  SDL_PIXELTYPE_UNKNOWN,
  SDL_PIXELTYPE_INDEX1,
  SDL_PIXELTYPE_INDEX4,
  SDL_PIXELTYPE_INDEX8,
  SDL_PIXELTYPE_PACKED8,
  SDL_PIXELTYPE_PACKED16,
  SDL_PIXELTYPE_PACKED32,
  SDL_PIXELTYPE_ARRAYU8,
  SDL_PIXELTYPE_ARRAYU16,
  SDL_PIXELTYPE_ARRAYU32,
  SDL_PIXELTYPE_ARRAYF16,
  SDL_PIXELTYPE_ARRAYF32
};

/** Bitmap pixel order, high bit -> low bit. */
enum {
  SDL_BITMAPORDER_NONE,
  SDL_BITMAPORDER_4321,
  SDL_BITMAPORDER_1234
};

/** Packed component order, high bit -> low bit. */
enum {
  SDL_PACKEDORDER_NONE,
  SDL_PACKEDORDER_XRGB,
  SDL_PACKEDORDER_RGBX,
  SDL_PACKEDORDER_ARGB,
  SDL_PACKEDORDER_RGBA,
  SDL_PACKEDORDER_XBGR,
  SDL_PACKEDORDER_BGRX,
  SDL_PACKEDORDER_ABGR,
  SDL_PACKEDORDER_BGRA
};

/** Array component order, low byte -> high byte. */
enum {
  SDL_ARRAYORDER_NONE,
  SDL_ARRAYORDER_RGB,
  SDL_ARRAYORDER_RGBA,
  SDL_ARRAYORDER_ARGB,
  SDL_ARRAYORDER_BGR,
  SDL_ARRAYORDER_BGRA,
  SDL_ARRAYORDER_ABGR
};

/** Packed component layout. */
enum {
  SDL_PACKEDLAYOUT_NONE,
  SDL_PACKEDLAYOUT_332,
  SDL_PACKEDLAYOUT_4444,
  SDL_PACKEDLAYOUT_1555,
  SDL_PACKEDLAYOUT_5551,
  SDL_PACKEDLAYOUT_565,
  SDL_PACKEDLAYOUT_8888,
  SDL_PACKEDLAYOUT_2101010,
  SDL_PACKEDLAYOUT_1010102
};

]]

local function SDL_FOURCC(a,b,c,d)
   return bit.bor(bit.lshift(bit.band(a,0xff),0),
                  bit.lshift(bit.band(b,0xff),8),
                  bit.lshift(bit.band(c,0xff),16),
                  bit.lshift(bit.band(d,0xff),24))
end

local SDL_DEFINE_PIXELFOURCC = SDL_FOURCC

local function SDL_DEFINE_PIXELFORMAT(type, order, layout, bits, bytes)
   return bit.bor(bit.lshift(1, 28),
                  bit.lshift(type, 24),
                  bit.lshift(order, 20),
                  bit.lshift(layout, 16),
                  bit.lshift(bits, 8),
                  bit.lshift(bytes, 0))
end

local pixelformat_enum_items = {
   sf("SDL_PIXELFORMAT_UNKNOWN"),
   sf("SDL_PIXELFORMAT_INDEX1LSB = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_INDEX1,
         ffi.C.SDL_BITMAPORDER_4321, 0, 1, 0)),
   sf("SDL_PIXELFORMAT_INDEX1MSB = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_INDEX1,
         ffi.C.SDL_BITMAPORDER_1234, 0, 1, 0)),
   sf("SDL_PIXELFORMAT_INDEX4LSB = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_INDEX4,
         ffi.C.SDL_BITMAPORDER_4321, 0, 4, 0)),
   sf("SDL_PIXELFORMAT_INDEX4MSB = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_INDEX4,
         ffi.C.SDL_BITMAPORDER_1234, 0, 4, 0)),
   sf("SDL_PIXELFORMAT_INDEX8 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_INDEX8, 0, 0, 8, 1)),
   sf("SDL_PIXELFORMAT_RGB332 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED8,
         ffi.C.SDL_PACKEDORDER_XRGB,
         ffi.C.SDL_PACKEDLAYOUT_332, 8, 1)),
   sf("SDL_PIXELFORMAT_RGB444 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_XRGB,
         ffi.C.SDL_PACKEDLAYOUT_4444, 12, 2)),
   sf("SDL_PIXELFORMAT_RGB555 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_XRGB,
         ffi.C.SDL_PACKEDLAYOUT_1555, 15, 2)),
   sf("SDL_PIXELFORMAT_BGR555 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_XBGR,
         ffi.C.SDL_PACKEDLAYOUT_1555, 15, 2)),
   sf("SDL_PIXELFORMAT_ARGB4444 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_ARGB,
         ffi.C.SDL_PACKEDLAYOUT_4444, 16, 2)),
   sf("SDL_PIXELFORMAT_RGBA4444 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_RGBA,
         ffi.C.SDL_PACKEDLAYOUT_4444, 16, 2)),
   sf("SDL_PIXELFORMAT_ABGR4444 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_ABGR,
         ffi.C.SDL_PACKEDLAYOUT_4444, 16, 2)),
   sf("SDL_PIXELFORMAT_BGRA4444 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_BGRA,
         ffi.C.SDL_PACKEDLAYOUT_4444, 16, 2)),
   sf("SDL_PIXELFORMAT_ARGB1555 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_ARGB,
         ffi.C.SDL_PACKEDLAYOUT_1555, 16, 2)),
   sf("SDL_PIXELFORMAT_RGBA5551 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_RGBA,
         ffi.C.SDL_PACKEDLAYOUT_5551, 16, 2)),
   sf("SDL_PIXELFORMAT_ABGR1555 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_ABGR,
         ffi.C.SDL_PACKEDLAYOUT_1555, 16, 2)),
   sf("SDL_PIXELFORMAT_BGRA5551 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_BGRA,
         ffi.C.SDL_PACKEDLAYOUT_5551, 16, 2)),
   sf("SDL_PIXELFORMAT_RGB565 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_XRGB,
         ffi.C.SDL_PACKEDLAYOUT_565, 16, 2)),
   sf("SDL_PIXELFORMAT_BGR565 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED16,
         ffi.C.SDL_PACKEDORDER_XBGR,
         ffi.C.SDL_PACKEDLAYOUT_565, 16, 2)),
   sf("SDL_PIXELFORMAT_RGB24 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_ARRAYU8,
         ffi.C.SDL_ARRAYORDER_RGB, 0, 24, 3)),
   sf("SDL_PIXELFORMAT_BGR24 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_ARRAYU8,
         ffi.C.SDL_ARRAYORDER_BGR, 0, 24, 3)),
   sf("SDL_PIXELFORMAT_RGB888 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED32,
         ffi.C.SDL_PACKEDORDER_XRGB,
         ffi.C.SDL_PACKEDLAYOUT_8888, 24, 4)),
   sf("SDL_PIXELFORMAT_RGBX8888 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED32,
         ffi.C.SDL_PACKEDORDER_RGBX,
         ffi.C.SDL_PACKEDLAYOUT_8888, 24, 4)),
   sf("SDL_PIXELFORMAT_BGR888 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED32,
         ffi.C.SDL_PACKEDORDER_XBGR,
         ffi.C.SDL_PACKEDLAYOUT_8888, 24, 4)),
   sf("SDL_PIXELFORMAT_BGRX8888 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED32,
         ffi.C.SDL_PACKEDORDER_BGRX,
         ffi.C.SDL_PACKEDLAYOUT_8888, 24, 4)),
   sf("SDL_PIXELFORMAT_ARGB8888 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED32,
         ffi.C.SDL_PACKEDORDER_ARGB,
         ffi.C.SDL_PACKEDLAYOUT_8888, 32, 4)),
   sf("SDL_PIXELFORMAT_RGBA8888 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED32,
         ffi.C.SDL_PACKEDORDER_RGBA,
         ffi.C.SDL_PACKEDLAYOUT_8888, 32, 4)),
   sf("SDL_PIXELFORMAT_ABGR8888 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED32,
         ffi.C.SDL_PACKEDORDER_ABGR,
         ffi.C.SDL_PACKEDLAYOUT_8888, 32, 4)),
   sf("SDL_PIXELFORMAT_BGRA8888 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED32,
         ffi.C.SDL_PACKEDORDER_BGRA,
         ffi.C.SDL_PACKEDLAYOUT_8888, 32, 4)),
   sf("SDL_PIXELFORMAT_ARGB2101010 = 0x%08x", SDL_DEFINE_PIXELFORMAT(
         ffi.C.SDL_PIXELTYPE_PACKED32,
         ffi.C.SDL_PACKEDORDER_ARGB,
         ffi.C.SDL_PACKEDLAYOUT_2101010, 32, 4)),
   sf("SDL_PIXELFORMAT_YV12 = 0x%08x", SDL_DEFINE_PIXELFOURCC(
         string.byte('Y'),
         string.byte('V'),
         string.byte('1'),
         string.byte('2'))),
   sf("SDL_PIXELFORMAT_IYUV = 0x%08x", SDL_DEFINE_PIXELFOURCC(
         string.byte('I'),
         string.byte('Y'),
         string.byte('U'),
         string.byte('V'))),
   sf("SDL_PIXELFORMAT_YUY2 = 0x%08x", SDL_DEFINE_PIXELFOURCC(
         string.byte('Y'),
         string.byte('U'),
         string.byte('Y'),
         string.byte('2'))),
   sf("SDL_PIXELFORMAT_UYVY = 0x%08x", SDL_DEFINE_PIXELFOURCC(
         string.byte('U'),
         string.byte('Y'),
         string.byte('V'),
         string.byte('Y'))),
   sf("SDL_PIXELFORMAT_YVYU = 0x%08x", SDL_DEFINE_PIXELFOURCC(
         string.byte('Y'),
         string.byte('V'),
         string.byte('Y'),
         string.byte('U'))),
}

-- generate a C enum for the pixelformats
local cdef = "enum {\n"
for i=1,#pixelformat_enum_items do
   cdef = cdef .. sf("  %s,\n", pixelformat_enum_items[i])
end
cdef = cdef .. "  SDL_PIXELFORMAT_LAST\n};\n"
-- and include it
ffi.cdef(cdef)

ffi.cdef [[

typedef struct SDL_Color {
  Uint8 r;
  Uint8 g;
  Uint8 b;
  Uint8 a;
} SDL_Color;

typedef struct SDL_Palette {
  int ncolors;
  SDL_Color *colors;
  Uint32 version;
  int refcount;
} SDL_Palette;

typedef struct SDL_PixelFormat {
  Uint32 format;
  SDL_Palette *palette;
  Uint8 BitsPerPixel;
  Uint8 BytesPerPixel;
  Uint8 padding[2];
  Uint32 Rmask;
  Uint32 Gmask;
  Uint32 Bmask;
  Uint32 Amask;
  Uint8 Rloss;
  Uint8 Gloss;
  Uint8 Bloss;
  Uint8 Aloss;
  Uint8 Rshift;
  Uint8 Gshift;
  Uint8 Bshift;
  Uint8 Ashift;
  int refcount;
  struct SDL_PixelFormat *next;
} SDL_PixelFormat;

const char* SDL_GetPixelFormatName(Uint32 format);
SDL_bool SDL_PixelFormatEnumToMasks(Uint32 format,
                                    int *bpp,
                                    Uint32 * Rmask,
                                    Uint32 * Gmask,
                                    Uint32 * Bmask,
                                    Uint32 * Amask);
Uint32 SDL_MapRGB(const SDL_PixelFormat * format,
                  Uint8 r, Uint8 g, Uint8 b);
Uint32 SDL_MapRGBA(const SDL_PixelFormat * format,
                   Uint8 r, Uint8 g, Uint8 b, Uint8 a);
void SDL_GetRGB(Uint32 pixel, const SDL_PixelFormat * format,
                Uint8 * r, Uint8 * g, Uint8 * b);
void SDL_GetRGBA(Uint32 pixel, const SDL_PixelFormat * format,
                 Uint8 * r, Uint8 * g, Uint8 * b, Uint8 * a);

/* SDL_video.h */

typedef struct {
  Uint32 format;              /**< pixel format */
  int w;                      /**< width */
  int h;                      /**< height */
  int refresh_rate;           /**< refresh rate (or zero for unspecified) */
  void *driverdata;           /**< driver-specific data, initialize to 0 */
} SDL_DisplayMode;

typedef struct SDL_Window SDL_Window;

typedef enum {
  SDL_WINDOW_FULLSCREEN         = 0x00000001, /**< fullscreen window */
  SDL_WINDOW_OPENGL             = 0x00000002, /**< window usable with OpenGL context */
  SDL_WINDOW_SHOWN              = 0x00000004, /**< window is visible */
  SDL_WINDOW_HIDDEN             = 0x00000008, /**< window is not visible */
  SDL_WINDOW_BORDERLESS         = 0x00000010, /**< no window decoration */
  SDL_WINDOW_RESIZABLE          = 0x00000020, /**< window can be resized */
  SDL_WINDOW_MINIMIZED          = 0x00000040, /**< window is minimized */
  SDL_WINDOW_MAXIMIZED          = 0x00000080, /**< window is maximized */
  SDL_WINDOW_INPUT_GRABBED      = 0x00000100, /**< window has grabbed input focus */
  SDL_WINDOW_INPUT_FOCUS        = 0x00000200, /**< window has input focus */
  SDL_WINDOW_MOUSE_FOCUS        = 0x00000400, /**< window has mouse focus */
  SDL_WINDOW_FULLSCREEN_DESKTOP = ( SDL_WINDOW_FULLSCREEN | 0x00001000 ),
  SDL_WINDOW_FOREIGN            = 0x00000800, /**< window not created by SDL */
  SDL_WINDOW_ALLOW_HIGHDPI      = 0x00002000  /**< window should be created in high-DPI mode if supported */
} SDL_WindowFlags;

static const uint32_t SDL_WINDOWPOS_UNDEFINED = 0x1FFF0000 | 0;
static const uint32_t SDL_WINDOWPOS_CENTERED  = 0x2FFF0000 | 0;

typedef enum {
  SDL_WINDOWEVENT_NONE,           /**< Never used */
  SDL_WINDOWEVENT_SHOWN,          /**< Window has been shown */
  SDL_WINDOWEVENT_HIDDEN,         /**< Window has been hidden */
  SDL_WINDOWEVENT_EXPOSED,        /**< Window has been exposed and should be redrawn */
  SDL_WINDOWEVENT_MOVED,          /**< Window has been moved to data1, data2 */
  SDL_WINDOWEVENT_RESIZED,        /**< Window has been resized to data1xdata2 */
  SDL_WINDOWEVENT_SIZE_CHANGED,   /**< The window size has changed, either as a result of an API call or through the system or user changing the window size. */
  SDL_WINDOWEVENT_MINIMIZED,      /**< Window has been minimized */
  SDL_WINDOWEVENT_MAXIMIZED,      /**< Window has been maximized */
  SDL_WINDOWEVENT_RESTORED,       /**< Window has been restored to normal size and position */
  SDL_WINDOWEVENT_ENTER,          /**< Window has gained mouse focus */
  SDL_WINDOWEVENT_LEAVE,          /**< Window has lost mouse focus */
  SDL_WINDOWEVENT_FOCUS_GAINED,   /**< Window has gained keyboard focus */
  SDL_WINDOWEVENT_FOCUS_LOST,     /**< Window has lost keyboard focus */
  SDL_WINDOWEVENT_CLOSE           /**< The window manager requests that the window be closed */
} SDL_WindowEventID;

typedef void *SDL_GLContext;

typedef enum {
  SDL_GL_RED_SIZE,
  SDL_GL_GREEN_SIZE,
  SDL_GL_BLUE_SIZE,
  SDL_GL_ALPHA_SIZE,
  SDL_GL_BUFFER_SIZE,
  SDL_GL_DOUBLEBUFFER,
  SDL_GL_DEPTH_SIZE,
  SDL_GL_STENCIL_SIZE,
  SDL_GL_ACCUM_RED_SIZE,
  SDL_GL_ACCUM_GREEN_SIZE,
  SDL_GL_ACCUM_BLUE_SIZE,
  SDL_GL_ACCUM_ALPHA_SIZE,
  SDL_GL_STEREO,
  SDL_GL_MULTISAMPLEBUFFERS,
  SDL_GL_MULTISAMPLESAMPLES,
  SDL_GL_ACCELERATED_VISUAL,
  SDL_GL_RETAINED_BACKING,
  SDL_GL_CONTEXT_MAJOR_VERSION,
  SDL_GL_CONTEXT_MINOR_VERSION,
  SDL_GL_CONTEXT_EGL,
  SDL_GL_CONTEXT_FLAGS,
  SDL_GL_CONTEXT_PROFILE_MASK,
  SDL_GL_SHARE_WITH_CURRENT_CONTEXT,
  SDL_GL_FRAMEBUFFER_SRGB_CAPABLE
} SDL_GLattr;

typedef enum {
  SDL_GL_CONTEXT_PROFILE_CORE           = 0x0001,
  SDL_GL_CONTEXT_PROFILE_COMPATIBILITY  = 0x0002,
  SDL_GL_CONTEXT_PROFILE_ES             = 0x0004
} SDL_GLprofile;

typedef enum {
  SDL_GL_CONTEXT_DEBUG_FLAG              = 0x0001,
  SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG = 0x0002,
  SDL_GL_CONTEXT_ROBUST_ACCESS_FLAG      = 0x0004,
  SDL_GL_CONTEXT_RESET_ISOLATION_FLAG    = 0x0008
} SDL_GLcontextFlag;

int SDL_GetNumVideoDisplays(void);
const char * SDL_GetDisplayName(int displayIndex);
int SDL_GetDisplayBounds(int displayIndex, SDL_Rect * rect);
int SDL_GetNumDisplayModes(int displayIndex);
int SDL_GetDisplayMode(int displayIndex, int modeIndex, SDL_DisplayMode * mode);
int SDL_GetDesktopDisplayMode(int displayIndex, SDL_DisplayMode * mode);
int SDL_GetCurrentDisplayMode(int displayIndex, SDL_DisplayMode * mode);
SDL_DisplayMode * SDL_GetClosestDisplayMode(int displayIndex,
                                            const SDL_DisplayMode * mode,
                                            SDL_DisplayMode * closest);

SDL_Window * SDL_CreateWindow(const char *title,
                              int x, int y, int w, int h,
                              Uint32 flags);

int SDL_GetWindowDisplayIndex(SDL_Window * window);
int SDL_GetWindowDisplayMode(SDL_Window * window, SDL_DisplayMode * mode);

Uint32 SDL_GetWindowID(SDL_Window * window);
void SDL_SetWindowIcon(SDL_Window * window, SDL_Surface * icon);

void SDL_ShowWindow(SDL_Window * window);
void SDL_HideWindow(SDL_Window * window);

void SDL_SetWindowGrab(SDL_Window * window, SDL_bool grabbed);
SDL_bool SDL_GetWindowGrab(SDL_Window * window);

void SDL_SetWindowSize(SDL_Window * window, int w, int h);
void SDL_GetWindowSize(SDL_Window * window, int *w, int *h);

void SDL_DestroyWindow(SDL_Window * window);

void SDL_GL_ResetAttributes(void);
int SDL_GL_SetAttribute(SDL_GLattr attr, int value);
int SDL_GL_GetAttribute(SDL_GLattr attr, int *value);

SDL_GLContext SDL_GL_CreateContext(SDL_Window * window);
int SDL_GL_MakeCurrent(SDL_Window * window, SDL_GLContext context);
SDL_Window* SDL_GL_GetCurrentWindow(void);
void SDL_GL_GetDrawableSize(SDL_Window * window, int *w, int *h);
int SDL_GL_SetSwapInterval(int interval);
int SDL_GL_GetSwapInterval(void);
void SDL_GL_SwapWindow(SDL_Window * window);
void SDL_GL_DeleteContext(SDL_GLContext context);

/* SDL_blendmode.h */

typedef enum {
  SDL_BLENDMODE_NONE  = 0x00000000,
  SDL_BLENDMODE_BLEND = 0x00000001,
  SDL_BLENDMODE_ADD   = 0x00000002,
  SDL_BLENDMODE_MOD   = 0x00000004
} SDL_BlendMode;

/* SDL_render.h */

typedef enum {
  SDL_RENDERER_SOFTWARE      = 0x0001,
  SDL_RENDERER_ACCELERATED   = 0x0002,
  SDL_RENDERER_PRESENTVSYNC  = 0x0004,
  SDL_RENDERER_TARGETTEXTURE = 0x0008
} SDL_RendererFlags;

typedef struct SDL_RendererInfo {
  const char *name;           /**< The name of the renderer */
  Uint32 flags;               /**< Supported ::SDL_RendererFlags */
  Uint32 num_texture_formats; /**< The number of available texture formats */
  Uint32 texture_formats[16]; /**< The available texture formats */
  int max_texture_width;      /**< The maximimum texture width */
  int max_texture_height;     /**< The maximimum texture height */
} SDL_RendererInfo;

typedef enum {
  SDL_TEXTUREACCESS_STATIC,
  SDL_TEXTUREACCESS_STREAMING,
  SDL_TEXTUREACCESS_TARGET
} SDL_TextureAccess;

typedef enum {
  SDL_TEXTUREMODULATE_NONE  = 0x0000,     /**< No modulation */
  SDL_TEXTUREMODULATE_COLOR = 0x0001,    /**< srcC = srcC * color */
  SDL_TEXTUREMODULATE_ALPHA = 0x0002     /**< srcA = srcA * alpha */
} SDL_TextureModulate;

typedef enum {
  SDL_FLIP_NONE       = 0x00000000,     /**< Do not flip */
  SDL_FLIP_HORIZONTAL = 0x00000001,    /**< flip horizontally */
  SDL_FLIP_VERTICAL   = 0x00000002     /**< flip vertically */
} SDL_RendererFlip;

typedef struct SDL_Renderer SDL_Renderer;
typedef struct SDL_Texture SDL_Texture;

int SDL_GetNumRenderDrivers(void);
int SDL_GetRenderDriverInfo(int index, SDL_RendererInfo * info);

SDL_Renderer * SDL_CreateRenderer(SDL_Window * window, 
                                  int index, Uint32 flags);
int SDL_GetRendererInfo(SDL_Renderer * renderer, SDL_RendererInfo * info);

SDL_Texture * SDL_CreateTexture(SDL_Renderer * renderer,
                                Uint32 format, int access,
                                int w, int h);
int SDL_UpdateTexture(SDL_Texture * texture, const SDL_Rect * rect,
                      const void *pixels, int pitch);
int SDL_LockTexture(SDL_Texture * texture, const SDL_Rect * rect,
                    void **pixels, int *pitch);
void SDL_UnlockTexture(SDL_Texture * texture);
int SDL_SetTextureBlendMode(SDL_Texture * texture, SDL_BlendMode blendMode);
void SDL_DestroyTexture(SDL_Texture * texture);

int SDL_SetRenderDrawColor(SDL_Renderer * renderer,
                           Uint8 r, Uint8 g, Uint8 b, Uint8 a);
int SDL_SetRenderDrawBlendMode(SDL_Renderer * renderer,
                               SDL_BlendMode blendMode);
int SDL_RenderClear(SDL_Renderer * renderer);
int SDL_RenderDrawPoint(SDL_Renderer * renderer, int x, int y);
int SDL_RenderDrawLine(SDL_Renderer * renderer, 
                       int x1, int y1, int x2, int y2);
int SDL_RenderDrawRect(SDL_Renderer * renderer, const SDL_Rect * rect);
int SDL_RenderFillRect(SDL_Renderer * renderer, const SDL_Rect * rect);
int SDL_RenderCopy(SDL_Renderer * renderer,
                   SDL_Texture * texture,
                   const SDL_Rect * srcrect,
                   const SDL_Rect * dstrect);
int SDL_RenderCopyEx(SDL_Renderer * renderer,
                     SDL_Texture * texture,
                     const SDL_Rect * srcrect,
                     const SDL_Rect * dstrect,
                     const double angle,
                     const SDL_Point *center,
                     const SDL_RendererFlip flip);
int SDL_RenderReadPixels(SDL_Renderer * renderer,
                         const SDL_Rect * rect,
                         Uint32 format,
                         void *pixels, int pitch);
int SDL_SetRenderTarget(SDL_Renderer *renderer, SDL_Texture *texture);
SDL_Texture * SDL_GetRenderTarget(SDL_Renderer *renderer);
void SDL_RenderPresent(SDL_Renderer * renderer);

void SDL_DestroyRenderer(SDL_Renderer * renderer);

/* SDL_syswm.h */

typedef enum
{
    SDL_SYSWM_UNKNOWN,
    SDL_SYSWM_WINDOWS,
    SDL_SYSWM_X11,
    SDL_SYSWM_DIRECTFB,
    SDL_SYSWM_COCOA,
    SDL_SYSWM_UIKIT,
    SDL_SYSWM_WAYLAND,
    SDL_SYSWM_MIR,
} SDL_SYSWM_TYPE;

typedef struct SDL_SysWMinfo SDL_SysWMinfo;

SDL_bool SDL_GetWindowWMInfo(SDL_Window * window, SDL_SysWMinfo * info);


]]

if ffi.os == "Linux" then
ffi.cdef [[
struct SDL_SysWMinfo {
  SDL_version version;
  SDL_SYSWM_TYPE subsystem;
  union {
    struct {
      Display *display;           /**< The X11 display */
      Window window;              /**< The X11 window */
    } x11;
    int dummy;
  } info;
};
]]
end

ffi.cdef [[

/* SDL_audio.h */

typedef void (*SDL_AudioCallback) (void *userdata,
                                   uint8_t * stream,
                                   int len);

int SDL_GetNumAudioDrivers(void);
const char *SDL_GetAudioDriver(int index);
const char *SDL_GetCurrentAudioDriver(void);
int SDL_GetNumAudioDevices(int iscapture);
const char *SDL_GetAudioDeviceName(int index, int iscapture);

typedef uint16_t SDL_AudioFormat;

enum {
  AUDIO_U8     = 0x0008,
  AUDIO_S8     = 0x8008,
  AUDIO_U16    = 0x0010,
  AUDIO_U16LSB = 0x0010,
  AUDIO_S16    = 0x8010,
  AUDIO_S16LSB = 0x8010,
  AUDIO_U16MSB = 0x1010,
  AUDIO_S16MSB = 0x9010,
  AUDIO_S32    = 0x8020,
  AUDIO_S32LSB = 0x8020,
  AUDIO_S32MSB = 0x9020,
  AUDIO_F32    = 0x8120,
  AUDIO_F32LSB = 0x8120,
  AUDIO_F32MSB = 0x9120,
};

]]

if ffi.abi("le") then
   ffi.cdef [[
enum {
  AUDIO_U16SYS = AUDIO_U16LSB,
  AUDIO_S16SYS = AUDIO_S16LSB,
  AUDIO_S32SYS = AUDIO_S32LSB,
  AUDIO_F32SYS = AUDIO_F32LSB,
};
]]
else
   ffi.cdef [[
enum {
  AUDIO_U16SYS = AUDIO_U16MSB,
  AUDIO_S16SYS = AUDIO_S16MSB,
  AUDIO_S32SYS = AUDIO_S32MSB,
  AUDIO_F32SYS = AUDIO_F32MSB,
};
]]
end

ffi.cdef [[

typedef struct SDL_AudioSpec {
  int freq;
  SDL_AudioFormat format;
  uint8_t channels;
  uint8_t silence;
  uint16_t samples;
  uint16_t padding;
  uint32_t size;
  SDL_AudioCallback callback;
  void *userdata;
} SDL_AudioSpec;

typedef uint32_t SDL_AudioDeviceID;
SDL_AudioDeviceID SDL_OpenAudioDevice(const char *device,
                                      int iscapture,
                                      const SDL_AudioSpec *desired,
                                      SDL_AudioSpec *obtained,
                                      int allowed_changes);

typedef enum {
  SDL_AUDIO_STOPPED = 0,
  SDL_AUDIO_PLAYING,
  SDL_AUDIO_PAUSED
} SDL_AudioStatus;

SDL_AudioStatus SDL_GetAudioStatus(void);
SDL_AudioStatus SDL_GetAudioDeviceStatus(SDL_AudioDeviceID dev);

void SDL_PauseAudio(int pause_on);
void SDL_PauseAudioDevice(SDL_AudioDeviceID dev, int pause_on);

void SDL_LockAudio(void);
void SDL_LockAudioDevice(SDL_AudioDeviceID dev);

void SDL_UnlockAudio(void);
void SDL_UnlockAudioDevice(SDL_AudioDeviceID dev);

void SDL_CloseAudio(void);
void SDL_CloseAudioDevice(SDL_AudioDeviceID dev);

]]

local sdl = ffi.load("SDL2")

local M = {}

M.DEFAULT_WINDOW_WIDTH  = 640
M.DEFAULT_WINDOW_HEIGHT = 480
M.DEFAULT_WINDOW_FLAGS = bit.bor(sdl.SDL_WINDOW_RESIZABLE,
                                 sdl.SDL_WINDOW_OPENGL)
M.DEFAULT_RENDERER_FLAGS = bit.bor(sdl.SDL_RENDERER_ACCELERATED,
                                   sdl.SDL_RENDERER_PRESENTVSYNC,
                                   sdl.SDL_RENDERER_TARGETTEXTURE)

M.SDL_INIT_FLAGS = sdl.SDL_INIT_AUDIO +
                   sdl.SDL_INIT_VIDEO +
                   sdl.SDL_INIT_EVENTS +
                   sdl.SDL_INIT_NOPARACHUTE

function M.Init()
   if sdl.SDL_WasInit(0) == 0 then
      util.check_ok("SDL_Init", 0, sdl.SDL_Init(M.SDL_INIT_FLAGS))
   end
end

function M.Quit()
   if sdl.SDL_WasInit(0) ~= 0 then
      sdl.SDL_Quit()
   end
end

function M.GetError()
   return ffi.string(sdl.SDL_GetError())
end

function M.GetPlatform()
   return ffi.string(sdl.SDL_GetPlatform())
end

function M.GetSystemRAM()
   return sdl.SDL_GetSystemRAM()
end

function M.GetCPUCount()
   return sdl.SDL_GetCPUCount()
end

function M.GetVersion()
   local version = ffi.new("SDL_version")
   sdl.SDL_GetVersion(version)
   return version.major, version.minor, version.patch
end

function M.GetNumVideoDisplays()
   return sdl.SDL_GetNumVideoDisplays()
end

function M.GetDisplayName(display_num)
   return ffi.string(sdl.SDL_GetDisplayName(display_num-1))
end

function M.GetDisplayBounds(display_num)
   local rect = ffi.new("SDL_Rect")
   sdl.SDL_GetDisplayBounds(display_num-1, rect)
   return rect
end

function M.GetNumDisplayModes(display_num)
   return sdl.SDL_GetNumDisplayModes(display_num-1)
end

function M.GetPixelFormatName(format)
   return ffi.string(sdl.SDL_GetPixelFormatName(format))
end

function M.PixelFormatEnumToMasks(format)
   local bpp = ffi.new("int[1]")
   local rmask = ffi.new("Uint32[1]")
   local gmask = ffi.new("Uint32[1]")
   local bmask = ffi.new("Uint32[1]")
   local amask = ffi.new("Uint32[1]")
   util.check_ok("SDL_PixelFormatEnumToMasks", sdl.SDL_TRUE,
                 sdl.SDL_PixelFormatEnumToMasks(format,
                                                bpp,
                                                rmask,
                                                gmask,
                                                bmask,
                                                amask))
   return bpp[0], rmask[0], gmask[0], bmask[0], amask[0]
end

local DisplayMode_mt = {}

function DisplayMode_mt:__tostring()
   return sf("%s %dx%d %dHz",
             M.GetPixelFormatName(self.format),
             self.w, self.h,
             self.refresh_rate)
end

local DisplayMode = ffi.metatype("SDL_DisplayMode", DisplayMode_mt)

function M.GetDisplayMode(display_num, mode_num)
   local mode = DisplayMode()
   sdl.SDL_GetDisplayMode(display_num-1, mode_num-1, mode)
   return mode
end

function M.GetDesktopDisplayMode(display_num)
   local mode = DisplayMode()
   sdl.SDL_GetDesktopDisplayMode(display_num-1, mode)
   return mode
end

function M.GetCurrentDisplayMode(display_num)
   local mode = DisplayMode()
   sdl.SDL_GetCurrentDisplayMode(display_num-1, mode)
   return mode
end

M.GetNumRenderDrivers = sdl.SDL_GetNumRenderDrivers

function M.GetRenderDriverInfo(index)
   local info = ffi.new("SDL_RendererInfo")
   util.check_ok("SDL_GetRenderDriverInfo", 0,
                 sdl.SDL_GetRenderDriverInfo(index-1, info))
   return info
end

-- Point

local Point_mt = {}

function Point_mt:__tostring()
   return sf("Point(%d,%d)", self.x, self.y)
end

M.Point = ffi.metatype("SDL_Point", Point_mt)

-- Rect

local Rect_mt = {}

function Rect_mt:__tostring()
   return sf("Rect(%d,%d,%d,%d)",
             self.x, self.y,
             self.w, self.h)
end

function Rect_mt:update(x,y,w,h)
   self.x = x or self.x
   self.y = y or self.y
   self.w = w or self.w
   self.h = h or self.h
end

function Rect_mt:clear()
   self:update(0,0,0,0)
end

M.Rect = ffi.metatype("SDL_Rect", Rect_mt)

-- Color

local Color_mt = {}

function Color_mt:bytes()
   return self.r, self.g, self.b, self.a
end

function Color_mt:floats()
   return self.r/255, self.g/255, self.b/255, self.a/255
end

function Color_mt:u32be()
   return
      bit.lshift(self.r, 24) +
      bit.lshift(self.g, 16) +
      bit.lshift(self.b, 8) +
      bit.lshift(self.a, 0)
end

function Color_mt:u32le()
   return
      bit.lshift(self.r, 0) +
      bit.lshift(self.g, 8) +
      bit.lshift(self.b, 16) +
      bit.lshift(self.a, 24)
end

Color_mt.__index = Color_mt

M.Color = ffi.metatype("SDL_Color", Color_mt)

-- Texture

local Texture_mt = {}

function Texture_mt:LockTexture(rect, pixels, pitch)
   local rv = sdl.SDL_LockTexture(self.texture, rect or self.rect,
                                  ffi.cast("void**", pixels),
                                  ffi.cast("int*", pitch))
   if rv ~= 0 then
      ef("SDL_LockTexture() failed: %s", M.GetError())
   end
end

function Texture_mt:UpdateTexture(rect, pixels, pitch)
   local rv = sdl.SDL_UpdateTexture(self.texture, rect,
                                    ffi.cast("const void*", pixels),
                                    pitch)
   if rv ~= 0 then
      ef("SDL_UpdateTexture() failed: %s", M.GetError())
   end
end

function Texture_mt.UnlockTexture()
   sdl.SDL_UnlockTexture(self.texture)
end

function Texture_mt:SetTextureBlendMode(mode)
   util.check_ok("SDL_SetTextureBlendMode", 0,
                 sdl.SDL_SetTextureBlendMode(self.texture, mode))
end
Texture_mt.blendmode = Texture_mt.SetTextureBlendMode

function Texture_mt:clear(color)
   local renderer = self.renderer
   local prev_render_target = renderer:GetRenderTarget()
   renderer:SetRenderTarget(self.texture)
   if color then
      renderer:SetRenderDrawColor(color)
   end
   renderer:RenderClear()
   renderer:SetRenderTarget(prev_render_target)
end

function Texture_mt:update(dst_rect, src, src_rect)
   dst_rect = dst_rect or self.rect
   if src.is_texture then
      local renderer = self.renderer
      local prev_render_target = renderer:GetRenderTarget()
      renderer:SetRenderTarget(self.texture)
      renderer:RenderCopy(src, src_rect or src.rect, dst_rect)
      renderer:SetRenderTarget(prev_render_target)
   elseif src.is_pixelbuffer then
      assert(self.format==src.format)
      self:UpdateTexture(dst_rect, src.buf, src.pitch)
   else
      ef("invalid update source: %s", src)
   end
end

function Texture_mt:DestroyTexture()
   if self.texture then
      sdl.SDL_DestroyTexture(self.texture)
      self.texture = nil
      self.rect = nil
   end
end
Texture_mt.delete = Texture_mt.DestroyTexture

Texture_mt.__index = Texture_mt
Texture_mt.__gc = Texture_mt.delete

-- Renderer

local Renderer_mt = {}

function Renderer_mt:GetRendererInfo()
   local info = ffi.new("SDL_RendererInfo")
   util.check_ok("SDL_GetRendererInfo", 0,
                 sdl.SDL_GetRendererInfo(self.renderer, info))
   return info
end

function Renderer_mt:CreateTexture(format, access, width, height)
   local texture = sdl.SDL_CreateTexture(self.renderer,
                                         format, access,
                                         width, height)
   if texture == nil then
      ef("Cannot create texture: %s", M.GetError())
   end
   local t = {
      is_texture = true,
      texture = texture,
      renderer = self,
      rect = M.Rect(0, 0, width, height),
      format = format,
      access = access,
      width = width,
      height = height,
   }
   return setmetatable(t, Texture_mt)
end

function Renderer_mt:SetRenderDrawColor(color)
   util.check_ok("SDL_SetRenderDrawColor", 0,
                 sdl.SDL_SetRenderDrawColor(self.renderer,
                                            color:bytes()))
end

function Renderer_mt:RenderClear()
   util.check_ok("SDL_RenderClear", 0,
                 sdl.SDL_RenderClear(self.renderer))
end

function Renderer_mt:RenderCopy(texture, src_rect, dst_rect)
   util.check_ok("SDL_RenderCopy", 0,
                 sdl.SDL_RenderCopy(self.renderer, texture.texture,
                                    src_rect, dst_rect))
end

function Renderer_mt:RenderReadPixels(rect, format, pixels, pitch)
   util.check_ok("SDL_RenderReadPixels", 0,
                 sdl.SDL_RenderReadPixels(self.renderer,
                                          rect, format,
                                          pixels, pitch))
end

function Renderer_mt:SetRenderTarget(target)
   local rv = sdl.SDL_SetRenderTarget(self.renderer, target)
   if rv ~= 0 then
      ef("SDL_SetRenderTarget() failed: %s", M.GetError())
   end
end

function Renderer_mt:GetRenderTarget()
   return sdl.SDL_GetRenderTarget(self.renderer)
end

function Renderer_mt:RenderPresent()
   sdl.SDL_RenderPresent(self.renderer)
end

function Renderer_mt:DestroyRenderer()
   if self.renderer then
      sdl.SDL_DestroyRenderer(self.renderer)
      self.renderer = nil
   end
end
Renderer_mt.delete = Renderer_mt.DestroyRenderer

Renderer_mt.__index = Renderer_mt
Renderer_mt.__gc = Renderer_mt.delete

-- Window

local Window_mt = {}

function Window_mt:ShowWindow()
   sdl.SDL_ShowWindow(self.window)
end

function Window_mt:HideWindow()
   sdl.SDL_HideWindow(self.window)
end

function Window_mt:GL_SwapWindow()
   sdl.SDL_GL_SwapWindow(self.window)
end

function Window_mt:GetWindowSize()
   local width = ffi.new("int[1]")
   local height = ffi.new("int[1]")
   sdl.SDL_GetWindowSize(self.window, width, height)
   return width[0], height[0]
end

function Window_mt:GetWindowDisplayMode()
   local mode = DisplayMode()
   sdl.SDL_GetWindowDisplayMode(self.window, mode)
   return mode
end

function Window_mt:GetWindowDisplayIndex()
   return sdl.SDL_GetWindowDisplayIndex(self.window)+1
end

function Window_mt:GetWindowWMInfo()
   local info = ffi.new("SDL_SysWMinfo")
   sdl.SDL_GetVersion(info.version)
   local rv = sdl.SDL_GetWindowWMInfo(self.window, info)
   if rv == sdl.SDL_TRUE then
      return info
   else
      ef("SDL_GetWindowWMInfo() failed: %s", M.GetError())
   end
end

function Window_mt:dpi()
   local info = self:GetWindowWMInfo()
   if ffi.os == "Linux" then
      local dpy = info.info.x11.display
      local width = xlib.XDisplayWidth(dpy, 0)
      local height = xlib.XDisplayHeight(dpy, 0)
      local width_mm = xlib.XDisplayWidthMM(dpy, 0)
      local height_mm = xlib.XDisplayHeightMM(dpy, 0)
      local width_inch = width_mm / 25.4 -- 1 inch = 2.54 cm = 25.4 mm
      local height_inch = height_mm / 25.4
      local xdpi = math.floor(width / width_inch + 0.5)
      local ydpi = math.floor(height / height_inch + 0.5)
      return xdpi, ydpi
   else
      ef("Window:dpi() is not implemented on this platform")
   end
end

function Window_mt:CreateRenderer(index, flags)
   index = (index or 0) - 1 -- received argument is one-based
   flags = flags or M.DEFAULT_RENDERER_FLAGS
   local renderer = sdl.SDL_CreateRenderer(self.window, index, flags)
   if renderer == nil then
      ef("Cannot create renderer: %s", M.GetError())
   end
   local r = { renderer = renderer }
   return setmetatable(r, Renderer_mt)
end

local Context_mt = {}

function Context_mt:GL_MakeCurrent()
   util.check_ok("SDL_GL_MakeCurrent", 0,
                 sdl.SDL_GL_MakeCurrent(self.window, self.ctx))
end

function Context_mt:GL_DeleteContext()
   if self.ctx then
      sdl.SDL_GL_DeleteContext(self.ctx)
      self.ctx = nil
   end
end
Context_mt.delete = Context_mt.GL_DeleteContext

Context_mt.__index = Context_mt
Context_mt.__gc = Context_mt.delete

function Window_mt:GL_CreateContext()
   local ctx = sdl.SDL_GL_CreateContext(self.window)
   if ctx == nil then
      ef("SDL_GL_CreateContext() failed: %s", M.GetError())
   end
   local c = {
      window = self.window,
      ctx = ctx,
   }
   return setmetatable(c, Context_mt)
end

function Window_mt:DestroyWindow()
   if self.window then
      sdl.SDL_DestroyWindow(self.window)
      self.window = nil
   end
end
Window_mt.delete = Window_mt.DestroyWindow

Window_mt.__index = Window_mt
Window_mt.__gc = Window_mt.delete

function M.CreateWindow(title, x, y, w, h, flags)
   x = x or sdl.SDL_WINDOWPOS_UNDEFINED
   if x == -1 then x = sdl.SDL_WINDOWPOS_CENTERED end
   y = y or sdl.SDL_WINDOWPOS_UNDEFINED
   if y == -1 then y = sdl.SDL_WINDOWPOS_CENTERED end
   w = w or M.DEFAULT_WINDOW_WIDTH
   h = h or M.DEFAULT_WINDOW_HEIGHT
   flags = flags or M.DEFAULT_WINDOW_FLAGS
   local window = sdl.SDL_CreateWindow(title, x, y, w, h, flags)
   if window == nil then
      ef("SDL_CreateWindow() failed: %s", M.GetError())
   end
   local win = { window = window }
   return setmetatable(win, Window_mt)
end

function M.GL_SetAttribute(attr, value)
   local rv = sdl.SDL_GL_SetAttribute(attr, value)
   if rv ~= 0 then
      ef("SDL_GL_SetAttribute(%d, %d) failed: %s",
         attr, value, M.GetError())
   end
end

function M.GL_GetAttribute(attr)
   local value = ffi.new("int[1]")
   local rv = sdl.SDL_GL_GetAttribute(attr, value)
   if rv ~= 0 then
      ef("SDL_GL_GetAttribute() failed: %s", M.GetError())
   end
   return value[0]
end

-- audio

M.GetNumAudioDrivers = sdl.SDL_GetNumAudioDrivers

function M.GetAudioDriver(index)
   local name = sdl.SDL_GetAudioDriver(index-1)
   if name == nil then
      ef("SDL_GetAudioDriver(%d) failed: invalid index", index-1)
   end
   return ffi.string(name)
end

function M.GetCurrentAudioDriver()
   local name = sdl.SDL_GetCurrentAudioDriver()
   if name == nil then
      ef("SDL_GetCurrentAudioDriver() failed")
   end
   return ffi.string(name)
end

function M.GetNumAudioDevices(iscapture)
   return sdl.SDL_GetNumAudioDevices(iscapture or 0)
end

function M.GetAudioDeviceName(index, iscapture)
   local name = sdl.SDL_GetAudioDeviceName(index-1, iscapture or 0)
   if name == nil then
      ef("SDL_GetAudioDeviceName(%d, %d) failed", index-1, iscapture)
   end
   return ffi.string(name)
end

local AudioDevice_mt = {}

local audio_status_names = {
   [sdl.SDL_AUDIO_STOPPED] = "stopped",
   [sdl.SDL_AUDIO_PLAYING] = "playing",
   [sdl.SDL_AUDIO_PAUSED] = "paused",
}

function AudioDevice_mt:status()
   local status = sdl.SDL_GetAudioDeviceStatus(self.dev)
   return audio_status_names[status]
end

function AudioDevice_mt:pause(pause_on)
   sdl.SDL_PauseAudioDevice(self.dev, pause_on)
end

function AudioDevice_mt:start()
   sdl.SDL_PauseAudioDevice(self.dev, 0)
end

function AudioDevice_mt:stop()
   sdl.SDL_PauseAudioDevice(self.dev, 1)
end

function AudioDevice_mt:lock()
   sdl.SDL_LockAudioDevice(self.dev)
end

function AudioDevice_mt:unlock()
   sdl.SDL_LockAudioDevice(self.dev)
end

function AudioDevice_mt:close()
   if self.dev then
      sdl.SDL_CloseAudioDevice(self.dev)
      self.dev = nil
   end
end
AudioDevice_mt.delete = AudioDevice_mt.close

AudioDevice_mt.__index = AudioDevice_mt
AudioDevice_mt.__gc = AudioDevice_mt.delete

function M.OpenAudioDevice(opts)
   local device = opts.device or nil
   if type(device)=="number" then
      device = M.GetAudioDeviceName(device)
   end
   local iscapture = opts.iscapture or 0
   local desired = ffi.new("SDL_AudioSpec")
   desired.freq = opts.freq or 44100
   desired.format = opts.format or sdl.AUDIO_S16SYS
   desired.channels = opts.channels or 2
   desired.samples = opts.samples or 512
   desired.callback = opts.callback
   desired.userdata = opts.userdata
   local obtained = ffi.new("SDL_AudioSpec")
   local allowed_changes = opts.allowed_changes or 0
   local dev = sdl.SDL_OpenAudioDevice(device, iscapture, desired, obtained, allowed_changes)
   if dev == 0 then
      ef("SDL_OpenAudioDevice() failed: %s", sdl.GetError())
   end
   local self = {
      dev = dev,
      id = dev,
      freq = obtained.freq,
      format = obtained.format,
      channels = obtained.channels,
      samples = obtained.samples,
      silence = obtained.silence,
      size = obtained.size,
   }
   return setmetatable(self, AudioDevice_mt)
end

function M.GetModState()
   return sdl.SDL_GetModState()
end

-- scheduler module

local function SDL2Module(sched)
   local self = { init = M.Init, done = M.Quit }
   local sdl_event_types = {
      [sdl.SDL_QUIT]                 = 'sdl.quit',
      [sdl.SDL_WINDOWEVENT]          = 'sdl.windowevent',
      [sdl.SDL_SYSWMEVENT]           = 'sdl.syswmevent',
      [sdl.SDL_KEYDOWN]              = 'sdl.keydown',
      [sdl.SDL_KEYUP]                = 'sdl.keyup',
      [sdl.SDL_MOUSEMOTION]          = 'sdl.mousemotion',
      [sdl.SDL_MOUSEBUTTONDOWN]      = 'sdl.mousebuttondown',
      [sdl.SDL_MOUSEBUTTONUP]        = 'sdl.mousebuttonup',
      [sdl.SDL_MOUSEWHEEL]           = 'sdl.mousewheel',
      [sdl.SDL_DROPFILE]             = 'sdl.dropfile',
      [sdl.SDL_RENDER_TARGETS_RESET] = 'sdl.render_targets_reset',
   }
   local tmp_event = ffi.new("SDL_Event")
   function self.tick()
      -- poll for SDL events and convert them to scheduler events
      sdl.SDL_PumpEvents()
      while sdl.SDL_PollEvent(tmp_event) == 1 do
         local evdata = ffi.new("SDL_Event", tmp_event) -- clone it
         local evtype = sdl_event_types[evdata.type]
         if evtype then
            sched.emit(evtype, evdata)
         end
      end
   end
   return self
end

sched.register_module(SDL2Module)

return setmetatable(M, { __index = sdl })
