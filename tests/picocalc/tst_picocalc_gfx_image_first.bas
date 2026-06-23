' tst_picocalc_gfx_image_first.bas -- IMAGE RESIZE FAST without GRAPHICS WINDOW.
Option Explicit

Print "image_first_start"
IMAGE RESIZE FAST 0, 0, 8, 8, 16, 16, 16, 16
TEXT 4, MM.VRES - 14, "IMAGE RESIZE FAST", , 1, 1, RGB(WHITE)
Pause 250
Print "image_first_done hres="; MM.HRES; " vres="; MM.VRES
