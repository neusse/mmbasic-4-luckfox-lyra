' tst_picocalc_gfx_blit_first.bas -- BLIT should initialise PicoCalc display.
Option Explicit

Print "blit_first_start"
BLIT 0, 0, 8, 8, 16, 16
Text 4, MM.VRES - 14, "BLIT first", , 1, 1, RGB(WHITE)
Pause 250
Print "blit_first_done hres="; MM.HRES; " vres="; MM.VRES
