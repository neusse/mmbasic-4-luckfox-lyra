' tst_picocalc_print_at_graphics.bas -- PRINT @(x,y) draws text on PicoCalc framebuffer.
Option Explicit

Dim Integer x%, y%, found%

Print "print_at_graphics_start"
CLS RGB(BLACK)
Color RGB(WHITE), RGB(BLACK)
Print @(20, 20) "HELLO"

found% = 0
For y% = 20 To 36
  For x% = 20 To 80
    If PIXEL(x%, y%) <> RGB(BLACK) Then found% = 1
  Next x%
Next y%

If found% = 0 Then Error "PRINT @ did not draw"
Print "print_at_graphics_done"
