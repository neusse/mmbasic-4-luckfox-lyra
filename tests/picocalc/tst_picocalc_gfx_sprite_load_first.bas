' tst_picocalc_gfx_sprite_load_first.bas -- SPRITE LOAD/SHOW without GRAPHICS WINDOW.
Option Explicit
Const SPR$ = "/tmp/mmb4l-tiny.spr"

Print "sprite_load_start"
Open SPR$ For Output As #1
Print #1, "2,1,2"
Print #1, "12"
Print #1, "34"
Close #1

SPRITE LOAD SPR$, 1, 1
SPRITE SHOW 1, 8, 8, 1
TEXT 4, MM.VRES - 14, "SPRITE LOAD", , 1, 1, RGB(WHITE)
Pause 250
Print "sprite_load_done hres="; MM.HRES; " vres="; MM.VRES
