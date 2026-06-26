' tst_picocalc_screen_console_cursor.bas -- Screen console cursor regressions.
Option Explicit

Dim Integer i%, x%, y%, topLit%

If MM.Info$(CONSOLE MODE) <> "SCREEN" Then
  Print "picocalc_screen_console_cursor: NO ASSERTIONS - set MMB4L_PICOCALC_CONSOLE=screen"
  End
EndIf

CLS
For i% = 1 To 5
  Print "line"
Next i%
CLS
Print "TOP";

topLit% = 0
For y% = 0 To MM.FONTHEIGHT * 2
  For x% = 0 To 80
    If Pixel(x%, y%) <> RGB(BLACK) Then topLit% = topLit% + 1
  Next x%
Next y%
If topLit% = 0 Then Error "CLS did not home screen cursor"

CLS
For i% = 1 To 35
  Print @(0, 0) "X"
Next i%

topLit% = 0
For y% = 0 To MM.FONTHEIGHT * 2
  For x% = 0 To 32
    If Pixel(x%, y%) <> RGB(BLACK) Then topLit% = topLit% + 1
  Next x%
Next y%
If topLit% = 0 Then Error "PRINT @ newline scrolled screen cursor"

CLS
Print "screen console cursor ok"
