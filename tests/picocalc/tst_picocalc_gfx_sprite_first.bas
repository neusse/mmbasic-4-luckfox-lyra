' tst_picocalc_gfx_sprite_first.bas -- SPRITE READ/SHOW without GRAPHICS WINDOW.
Option Explicit

Print "sprite_first_start"
SPRITE READ 1, 0, 0, 8, 8
SPRITE SHOW 1, 16, 16, 1
SPRITE NEXT 1, 24, 24
SPRITE MOVE
SPRITE HIDE 1
TEXT 4, MM.VRES - 14, "SPRITE READ/SHOW", , 1, 1, RGB(WHITE)
Pause 250
Print "sprite_first_done hres="; MM.HRES; " vres="; MM.VRES
