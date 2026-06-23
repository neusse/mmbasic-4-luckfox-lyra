' tst_picocalc_gfx_blit_rw_first.bas -- BLIT READ/WRITE without GRAPHICS WINDOW.
Option Explicit

Print "blit_rw_start"
BLIT READ 1, 0, 0, 8, 8
BLIT WRITE 1, 16, 16
TEXT 4, MM.VRES - 14, "BLIT READ/WRITE", , 1, 1, RGB(WHITE)
Pause 250
Print "blit_rw_done hres="; MM.HRES; " vres="; MM.VRES
