' tst_picocalc_gfx_pixel_function.bas -- PIXEL(x, y) reads active surface colour.
Option Explicit

Dim c%

Print "pixel_function_start"
CLS RGB(BLACK)
PIXEL 8, 8, RGB(RED)
c% = PIXEL(8, 8)
If c% <> RGB(RED) Then
  Error "PIXEL(8,8) returned " + Str$(c%)
EndIf
TEXT 4, MM.VRES - 14, "PIXEL()", , 1, 1, RGB(WHITE)
Pause 250
Print "pixel_function_done value="; c%; " hres="; MM.HRES; " vres="; MM.VRES
