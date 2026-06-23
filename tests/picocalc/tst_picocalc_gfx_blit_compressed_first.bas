' tst_picocalc_gfx_blit_compressed_first.bas -- BLIT COMPRESSED without GRAPHICS WINDOW.
Option Explicit

Dim buf%(1)
Dim addr% = Peek(VarAddr buf%())

Print "blit_compressed_start"
Poke Short addr%, &h8002
Poke Short addr% + 2, 2
Poke Byte addr% + 4, &h44
BLIT COMPRESSED addr%, 8, 8
TEXT 4, MM.VRES - 14, "BLIT COMPRESSED", , 1, 1, RGB(WHITE)
Pause 250
Print "blit_compressed_done hres="; MM.HRES; " vres="; MM.VRES
