' tst_picocalc_beep_noop.bas -- BEEP is accepted as a PicoCalc compatibility no-op.
Option Explicit

Print "beep_noop_start"
BEEP
BEEP 100, 50
Print "beep_noop_done"
