' tst_picocalc_continuation_lines.bas -- PicoMite-style space-underscore line continuation.
Option Explicit

Dim Integer a = 1, b = 2, c = 3, d = 4, e = 0

e = (a < b) + _
    (c < d) * 2 + _
    (a <= b) * 3
If e <> 6 Then Error "continuation arithmetic failed"

e = (a < b) + _
    (a < 0 Or a > 10 Or c < 0 Or c > 10) * 2 + _
    (a <= b) * 3
If e <> 4 Then Error "continued boolean expression failed"

Print "picocalc continuation lines ok"
End
