' tst_picocalc_text_graphics_layering.bas -- text overlays graphics without losing layers.
Option Explicit

Dim Integer x%, y%
Dim Integer white%, red%, blue%, green%

Print "text_graphics_layering_start"

' TEXT should draw white pixels over a red graphics background while red remains.
CLS RGB(BLACK)
Box 10, 10, 140, 44, 1, RGB(RED), RGB(RED)
TEXT 14, 18, "TEXT", , 1, 1, RGB(WHITE)

white% = 0 : red% = 0
For y% = 10 To 54
  For x% = 10 To 150
    If PIXEL(x%, y%) = RGB(WHITE) Then white% = white% + 1
    If PIXEL(x%, y%) = RGB(RED) Then red% = red% + 1
  Next x%
Next y%

If white% = 0 Then Error "TEXT did not overlay graphics"
If red% = 0 Then Error "TEXT erased graphics background"

' PRINT @ should also draw onto the graphics surface without losing background.
Box 10, 70, 140, 44, 1, RGB(BLUE), RGB(BLUE)
Color RGB(WHITE), RGB(BLUE)
Print @(14, 78) "PRINT"

white% = 0 : blue% = 0
For y% = 70 To 114
  For x% = 10 To 150
    If PIXEL(x%, y%) = RGB(WHITE) Then white% = white% + 1
    If PIXEL(x%, y%) = RGB(BLUE) Then blue% = blue% + 1
  Next x%
Next y%

If white% = 0 Then Error "PRINT @ did not overlay graphics"
If blue% = 0 Then Error "PRINT @ erased graphics background"

' FRAMEBUFFER LAYER text should merge over F while preserving F background.
FRAMEBUFFER CREATE
FRAMEBUFFER LAYER
FRAMEBUFFER WRITE F
CLS RGB(GREEN)
FRAMEBUFFER WRITE L
TEXT 14, 138, "LAYER", , 1, 1, RGB(WHITE)
FRAMEBUFFER MERGE
FRAMEBUFFER WRITE N

white% = 0 : green% = 0
For y% = 130 To 174
  For x% = 10 To 170
    If PIXEL(x%, y%) = RGB(WHITE) Then white% = white% + 1
    If PIXEL(x%, y%) = RGB(GREEN) Then green% = green% + 1
  Next x%
Next y%

If white% = 0 Then Error "FRAMEBUFFER LAYER text did not merge"
If green% = 0 Then Error "FRAMEBUFFER LAYER erased F background"

FRAMEBUFFER CLOSE
Print "text_graphics_layering_done"
