' tst_picocalc_drive_noop.bas -- DRIVE is accepted as a PicoCalc compatibility no-op.
Option Explicit

Dim before$ = Cwd$

Print "drive_noop_start"
Drive "B:"
If Cwd$ <> before$ Then Error "DRIVE changed current directory"
Drive "A:"
If Cwd$ <> before$ Then Error "DRIVE changed current directory"
Print "drive_noop_done"
