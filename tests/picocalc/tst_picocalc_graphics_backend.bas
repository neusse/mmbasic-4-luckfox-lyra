Option Explicit

CLS RGB(BLACK)

Dim backend$ = MM.Info$(GRAPHICS BACKEND)

If backend$ <> "FBDEV" Then
  Error "Expected FBDEV graphics backend, got " + backend$
EndIf

Print "graphics backend ok: " + backend$
