' tst_picocalc_gfx_blit_memory_first.bas -- BLIT MEMORY without GRAPHICS WINDOW.
Option Explicit

Dim buf%(1)
Dim addr% = Peek(VarAddr buf%())

Print "blit_memory_start"
Poke Short addr%, 4
Poke Short addr% + 2, 2
Poke Byte addr% + 4, &h21
Poke Byte addr% + 5, &h43
Poke Byte addr% + 6, &h65
Poke Byte addr% + 7, &h87
BLIT MEMORY addr%, 8, 8
TEXT 4, MM.VRES - 14, "BLIT MEMORY", , 1, 1, RGB(WHITE)
Pause 250
Print "blit_memory_done hres="; MM.HRES; " vres="; MM.VRES
