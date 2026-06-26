Option Explicit

Dim k$, deadline!

If MM.Info$(ENVVAR "MMB4L_PICOCALC_EVDEV") = "" Then
    Print "SKIP: set MMB4L_PICOCALC_EVDEV to run evdev injection test"
    End
EndIf

deadline! = Timer + 2000

Do
    k$ = Inkey$
    If k$ <> "" Then Exit Do
    Pause 10
Loop Until Timer > deadline!

If k$ <> "a" Then Error "Expected evdev input 'a'"
