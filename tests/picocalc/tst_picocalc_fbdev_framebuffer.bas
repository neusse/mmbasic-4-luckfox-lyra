Option Explicit

CLS RGB(BLACK)

If MM.Info$(GRAPHICS BACKEND) <> "FBDEV" Then Error "FBDEV backend required"

FRAMEBUFFER CREATE
FRAMEBUFFER WRITE F
CLS RGB(BLACK)
BOX 10, 10, 80, 60, 1, RGB(RED), RGB(RED)
TEXT 12, 70, "F", , 1, 1, RGB(WHITE)
FRAMEBUFFER WRITE N
CLS RGB(BLACK)
FRAMEBUFFER COPY F, N
FRAMEBUFFER WAIT
Pause 250

If Pixel(20, 20) <> RGB(RED) Then Error "Framebuffer copy failed"
Print "fbdev framebuffer ok"
