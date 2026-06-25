' tst_picocalc_sprite_page_id_separation.bas -- SPRITE ids must not collide with PAGE ids.
Option Explicit

Print "sprite_page_id_start"
Cls Rgb(Black)
Page Write 1
Cls Rgb(Black)
Box 0, 0, 8, 8, 1, Rgb(White), Rgb(Green)
Sprite Read 1, 0, 0, 8, 8
Page Write 0
Sprite Show 1, 12, 12, 1
If Pixel(13, 13) <> Rgb(Green) Then Error "SPRITE 1 did not draw from PAGE 1 capture"
Sprite Hide 1
Sprite Close 1
Print "sprite_page_id_done"
