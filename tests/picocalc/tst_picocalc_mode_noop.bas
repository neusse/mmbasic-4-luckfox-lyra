' tst_picocalc_mode_noop.bas -- MODE compatibility on fixed PicoCalc framebuffer.
Option Explicit

Print "mode_noop_start"
MODE 1
If MM.HRES <> 320 Then Error "MODE changed MM.HRES to " + Str$(MM.HRES)
If MM.VRES <> 320 Then Error "MODE changed MM.VRES to " + Str$(MM.VRES)
CLS RGB(BLACK)
TEXT 4, MM.VRES - 14, "MODE 1 OK", , 1, 1, RGB(WHITE)
Pause 250
Print "mode_noop_done hres="; MM.HRES; " vres="; MM.VRES
