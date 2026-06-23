Option Explicit

Print "device_before="; MM.Device$
Graphics Window 0, 320, 320, , , "PicoCalc gfx window", 1
Graphics Write 0
Print "hres="; MM.HRES; " vres="; MM.VRES

Cls RGB(BLACK)
Pixel 0, 0, RGB(RED)
Pixel MM.HRES - 1, 0, RGB(GREEN)
Pixel 0, MM.VRES - 1, RGB(BLUE)
Pixel MM.HRES - 1, MM.VRES - 1, RGB(WHITE)
Line 0, 0, MM.HRES - 1, MM.VRES - 1, 1, RGB(YELLOW)
Box 8, 8, MM.HRES - 16, MM.VRES - 16, 1, RGB(CYAN)
Text 4, MM.VRES - 14, "PicoCalc gfx window", , 1, 1, RGB(WHITE)
Graphics Copy 0 To 0

Print "gfx_window_done"
Pause 500
End
