' tst_picocalc_csub_setint.bas -- CSUB dispatch smoke test.
Option Explicit
Print "csub_setint_start"
Dim x% = 0
setint x%
If x% <> 123 Then Error "CSUB did not update integer"
Print "csub_setint_done x=";x%

CSUB setint INTEGER
00000000 2300227B 2300E9C0 20002100 00004770
END CSUB
