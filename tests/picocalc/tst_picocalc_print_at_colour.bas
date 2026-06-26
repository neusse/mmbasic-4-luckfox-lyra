' tst_picocalc_print_at_colour.bas -- PRINT @ preserves current foreground/background colours.
Option Explicit

CLS RGB(BLACK)
Color RGB(RED), RGB(GREEN)
Print @(0, 0) "X"

If Pixel(1, 1) <> RGB(RED) Then Error "PRINT @ foreground colour was not preserved"
If Pixel(4, 4) <> RGB(GREEN) Then Error "PRINT @ background colour was not preserved"

CLS RGB(BLACK)
Print "print_at_colour ok"
