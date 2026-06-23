' tst_picocalc_gfx_load_png.bas -- LOAD PNG without GRAPHICS WINDOW.
Option Explicit
Const PNG$ = "/tmp/mmb4l-tiny-rgb.png"

Print "load_png_start"
LOAD PNG PNG$, 8, 8
TEXT 4, MM.VRES - 14, "LOAD PNG", , 1, 1, RGB(WHITE)
Pause 250
Print "load_png_done hres="; MM.HRES; " vres="; MM.VRES
