' tst_picocalc_print_at_semicolon_isolated.bas -- PRINT @ cursor does not leak to later PRINT.
Option Explicit

Dim Integer x%, y%, found%, fw%, fh%

Print "print_at_semicolon_isolated_start"
CLS RGB(BLACK)
Color RGB(WHITE), RGB(BLACK)

fw% = MM.FONTWIDTH
fh% = MM.FONTHEIGHT

Print @(0, 0) "A";
Print "A"

found% = 0
For y% = 0 To fh% - 1
  For x% = fw% To (fw% * 2) - 1
    If PIXEL(x%, y%) <> RGB(BLACK) Then found% = 1
  Next x%
Next y%

If found% <> 0 Then Error "PRINT @ cursor leaked"
Print "print_at_semicolon_isolated_done"
