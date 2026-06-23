' tst_picocalc_gfx_fullscreen_window.bas -- explicit 320x320 window should fill PicoCalc fb.
Option Explicit
Print "fullscreen_window_start"
Graphics Window 0, 320, 320, , , "PicoCalc fullscreen", 1
Graphics Write 0
Cls RGB(RED)
Pixel 0, 0, RGB(RED)
Pixel MM.HRES - 1, 0, RGB(RED)
Pixel 0, MM.VRES - 1, RGB(RED)
Pixel MM.HRES - 1, MM.VRES - 1, RGB(RED)
Graphics Copy 0 To 0
Pause 3000
Print "fullscreen_window_done"
