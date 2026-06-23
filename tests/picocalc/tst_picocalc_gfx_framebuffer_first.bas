' tst_picocalc_gfx_framebuffer_first.bas -- FRAMEBUFFER CREATE/WRITE on PicoCalc.
Option Explicit
Print "framebuffer_start"
CLS RGB(BLACK)
FRAMEBUFFER CREATE
FRAMEBUFFER WRITE F
CLS RGB(BLACK)
PIXEL 3, 3, RGB(RED)
If PIXEL(3, 3) <> RGB(RED) Then Error "framebuffer write"
FRAMEBUFFER WRITE N
If PIXEL(3, 3) = RGB(RED) Then Error "framebuffer leaked to N"
FRAMEBUFFER COPY F, N
If PIXEL(3, 3) <> RGB(RED) Then Error "framebuffer copy"
FRAMEBUFFER CLOSE F
Print "framebuffer_done hres=";MM.HRES;" vres=";MM.VRES
