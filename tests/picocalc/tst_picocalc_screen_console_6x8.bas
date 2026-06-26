' tst_picocalc_screen_console_6x8.bas -- Screen console uses 6x8 text.
Option Explicit

Dim Integer x%, y%, lastColLit%, wrappedLit%

If MM.Info$(CONSOLE MODE) <> "SCREEN" Then
  Print "picocalc_screen_console_6x8: NO ASSERTIONS - set MMB4L_PICOCALC_CONSOLE=screen"
  End
EndIf

CLS
Print "12345678901234567890123456789012345678901234567890123"; "Y";

lastColLit% = 0
For y% = 0 To 7
  For x% = 312 To 317
    If Pixel(x%, y%) <> RGB(BLACK) Then lastColLit% = lastColLit% + 1
  Next x%
Next y%
If lastColLit% = 0 Then Error "53rd screen-console column was not drawn"

wrappedLit% = 0
For y% = 8 To 15
  For x% = 0 To 5
    If Pixel(x%, y%) <> RGB(BLACK) Then wrappedLit% = wrappedLit% + 1
  Next x%
Next y%
If wrappedLit% = 0 Then Error "54th screen-console character did not wrap to next row"

CLS
Print "screen console 6x8 ok"
