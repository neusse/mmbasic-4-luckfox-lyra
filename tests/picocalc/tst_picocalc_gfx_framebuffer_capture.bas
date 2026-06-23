' tst_picocalc_gfx_framebuffer_capture.bas -- visible FRAMEBUFFER F -> N verification pattern.
Option Explicit
Print "framebuffer_capture_start"

CLS RGB(BLACK)
FRAMEBUFFER CREATE

FRAMEBUFFER WRITE F
CLS RGB(BLACK)
Box 0, 0, 160, 160, 1, RGB(255, 0, 0), RGB(255, 0, 0)
Box 160, 0, 160, 160, 1, RGB(0, 255, 0), RGB(0, 255, 0)
Box 0, 160, 160, 160, 1, RGB(0, 0, 255), RGB(0, 0, 255)
Box 160, 160, 160, 160, 1, RGB(255, 255, 255), RGB(255, 255, 255)

FRAMEBUFFER WRITE N
CLS RGB(BLACK)
If PIXEL(40, 40) <> RGB(BLACK) Then Error "N changed before framebuffer copy"

FRAMEBUFFER COPY F, N
If PIXEL(40, 40) <> RGB(255, 0, 0) Then Error "red quadrant"
If PIXEL(240, 40) <> RGB(0, 255, 0) Then Error "green quadrant"
If PIXEL(40, 240) <> RGB(0, 0, 255) Then Error "blue quadrant"
If PIXEL(240, 240) <> RGB(255, 255, 255) Then Error "white quadrant"

Print "framebuffer_capture_ready hres=";MM.HRES;" vres=";MM.VRES
Pause 3000
FRAMEBUFFER CLOSE F
Print "framebuffer_capture_done"
