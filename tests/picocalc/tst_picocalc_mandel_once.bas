Option Explicit
Const MAX% = 24
Dim W% = MM.HRES, H% = MM.VRES
Dim SW% = 80, SH% = 80, SCALE% = 4
Dim X%, Y%, PX%, PY%, I%, R%, G%, B%, C%
Dim CR!, CI!, ZR!, ZI!, TMP!

CLS RGB(BLACK)
For Y% = 0 To SH% - 1
    CI! = (Y% - SH% / 2) * 2.4 / SH%
    For X% = 0 To SW% - 1
        CR! = (X% - SW% / 2) * 3.5 / SW% - 0.5
        ZR! = 0 : ZI! = 0
        I% = 0
        Do While ZR! * ZR! + ZI! * ZI! < 4 And I% < MAX%
            TMP! = ZR! * ZR! - ZI! * ZI! + CR!
            ZI! = 2 * ZR! * ZI! + CI!
            ZR! = TMP!
            I% = I% + 1
        Loop
        PX% = X% * SCALE%
        PY% = Y% * SCALE%
        If I% = MAX% Then
            C% = RGB(BLACK)
        Else
            R% = (I% * 8) Mod 256
            G% = (I% * 16) Mod 256
            B% = (I% * 32) Mod 256
            C% = RGB(R%, G%, B%)
        EndIf
        Box PX%, PY%, SCALE%, SCALE%, 1, C%, C%
    Next X%
Next Y%

Text 4, H% - 14, "Mandelbrot smoke", , 1, 1, RGB(WHITE)
Print "mandel_once_done "; W%; "x"; H%; " sample "; SW%; "x"; SH%; " scale "; SCALE%
Pause 2000
End
