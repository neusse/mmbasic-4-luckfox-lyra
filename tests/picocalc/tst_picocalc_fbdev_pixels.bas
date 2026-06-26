Option Explicit

If MM.Info$(GRAPHICS BACKEND) <> "FBDEV" Then
  Error "FBDEV backend required"
EndIf

CLS RGB(BLACK)
PIXEL 0, 0, RGB(RED)
PIXEL MM.HRES - 1, 0, RGB(GREEN)
PIXEL 0, MM.VRES - 1, RGB(BLUE)
PIXEL MM.HRES - 1, MM.VRES - 1, RGB(WHITE)
TEXT 4, MM.VRES - 14, "FBDEV", , 1, 1, RGB(WHITE)
Pause 250

Print "fbdev pixel smoke ok"
