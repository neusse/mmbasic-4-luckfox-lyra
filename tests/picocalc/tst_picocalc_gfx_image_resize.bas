' tst_picocalc_gfx_image_resize.bas -- IMAGE RESIZE writes scaled pixels.
Option Explicit

Print "image_resize_start"
CLS RGB(BLACK)
PIXEL 2, 2, RGB(RED)
IMAGE RESIZE 2, 2, 1, 1, 8, 8, 3, 3
If PIXEL(8, 8) <> RGB(RED) Then Error "resize top-left"
If PIXEL(10, 10) <> RGB(RED) Then Error "resize bottom-right"
TEXT 4, MM.VRES - 14, "IMAGE RESIZE", , 1, 1, RGB(WHITE)
Pause 250
Print "image_resize_done hres="; MM.HRES; " vres="; MM.VRES
