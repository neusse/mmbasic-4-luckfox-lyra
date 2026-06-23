' tst_picocalc_gfx_image_rotate.bas -- IMAGE ROTATE writes rotated pixels.
Option Explicit

Print "image_rotate_start"
CLS RGB(BLACK)
PIXEL 3, 2, RGB(RED)
IMAGE ROTATE 2, 2, 3, 3, 8, 8, 90
If PIXEL(10, 9) <> RGB(RED) Then Error "rotate 90 clockwise"
CLS RGB(BLACK)
PIXEL 3, 2, RGB(RED)
IMAGE ROTATE FAST 2, 2, 3, 3, 8, 8, 90
If PIXEL(10, 9) <> RGB(RED) Then Error "rotate fast 90 clockwise"
TEXT 4, MM.VRES - 14, "IMAGE ROTATE", , 1, 1, RGB(WHITE)
Pause 250
Print "image_rotate_done hres="; MM.HRES; " vres="; MM.VRES
