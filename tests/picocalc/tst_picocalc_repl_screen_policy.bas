Option Explicit

CLS RGB(BLACK)

If MM.Info$(GRAPHICS BACKEND) <> "FBDEV" Then Error "FBDEV backend required"
If MM.Info$(CONSOLE MODE) <> "TERMINAL" Then Error "Console mode should default to terminal"

Print "console policy terminal-safe"
CLS RGB(BLACK)
TEXT 4, 4, "graphics still works", , 1, 1, RGB(WHITE)
FRAMEBUFFER WAIT
Pause 100
Print "console policy ok"
