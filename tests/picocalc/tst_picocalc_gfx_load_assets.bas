' tst_picocalc_gfx_load_assets.bas -- LOAD BMP/IMAGE without GRAPHICS WINDOW.
Option Explicit
Const BMP$ = "/usr/local/share/mmb4l/tests/graphics/assets/bmp/valid/24bpp-1x1.bmp"

Print "load_assets_start"
LOAD BMP BMP$, 8, 8
LOAD IMAGE BMP$, 18, 8
TEXT 4, MM.VRES - 14, "LOAD BMP/IMAGE", , 1, 1, RGB(WHITE)
Pause 250
Print "load_assets_done hres="; MM.HRES; " vres="; MM.VRES
