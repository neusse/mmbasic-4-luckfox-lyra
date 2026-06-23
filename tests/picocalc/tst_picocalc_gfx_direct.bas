Option Explicit

Print "device="; MM.Device$
Print "hres="; MM.HRES; " vres="; MM.VRES

Pixel 0, 0, RGB(RED)
Pixel MM.HRES - 1, 0, RGB(GREEN)
Pixel 0, MM.VRES - 1, RGB(BLUE)
Pixel MM.HRES - 1, MM.VRES - 1, RGB(WHITE)
Line 0, 0, MM.HRES - 1, MM.VRES - 1, 1, RGB(YELLOW)
Box 8, 8, MM.HRES - 16, MM.VRES - 16, 1, RGB(CYAN)
Text 4, MM.VRES - 14, "PicoCalc gfx direct", , 1, 1, RGB(WHITE)

Print "gfx_direct_done"
Pause 500
End
