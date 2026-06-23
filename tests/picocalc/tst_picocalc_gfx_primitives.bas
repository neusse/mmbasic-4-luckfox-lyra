' tst_picocalc_gfx_primitives.bas -- drawing primitives without GRAPHICS WINDOW.
Option Explicit
Dim X%(5), Y%(5)

Print "primitive_start"

CLS RGB(BLACK)
ARC 160, 160, 20, 38, 20, 300, RGB(WHITE)
CIRCLE 80, 80, 24, 2, 1, RGB(GREEN), RGB(BLUE)
RBOX 190, 30, 90, 50, 8, RGB(YELLOW), RGB(RED)
TRIANGLE 40, 230, 95, 180, 145, 235, RGB(CYAN), RGB(MAGENTA)

X%(0) = 180 : Y%(0) = 210
X%(1) = 220 : Y%(1) = 185
X%(2) = 275 : Y%(2) = 220
X%(3) = 250 : Y%(3) = 260
X%(4) = 195 : Y%(4) = 255
POLYGON 5, X%(), Y%(), RGB(WHITE), RGB(MYRTLE)

BLIT 0, 0, 8, 8, 32, 32
TEXT 4, MM.VRES - 14, "Primitive smoke", , 1, 1, RGB(WHITE)
Pause 500
Print "primitive_done hres="; MM.HRES; " vres="; MM.VRES
