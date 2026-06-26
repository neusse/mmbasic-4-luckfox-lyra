' tst_picocalc_screen_console_vt100.bas -- Screen console ANSI/VT100 handling.
Option Explicit

Dim Integer x%, y%, lit%

If MM.Info$(CONSOLE MODE) <> "SCREEN" Then
  Print "picocalc_screen_console_vt100: NO ASSERTIONS - set MMB4L_PICOCALC_CONSOLE=screen"
  End
EndIf

CLS
Print "ABC";
Print Chr$(27) + "[2J";

lit% = 0
For y% = 0 To MM.FONTHEIGHT * 2
  For x% = 0 To 80
    If Pixel(x%, y%) <> RGB(BLACK) Then lit% = lit% + 1
  Next x%
Next y%
If lit% <> 0 Then Error "VT100 clear sequence rendered text"

Print Chr$(27) + "[2;3H";
Print "Z";
If Pixel(0, 0) <> RGB(BLACK) Then Error "VT100 cursor movement wrote at home"

Print Chr$(27) + "[2J";
Print "screen console vt100 ok"
