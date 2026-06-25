' tst_picocalc_web_scan_array.bas -- WEB SCAN array%() compatibility smoke test.
Option Explicit
Print "web_scan_array_start"
If MM.INFO(WIFI STATUS) = 0 Then
  Print "web_scan_array: NO ASSERTIONS - no WiFi"
  End
EndIf
Dim scan%(1024)
WEB SCAN scan%()
If LLen(scan%()) < 0 Then Error "bad scan length"
Print "web_scan_array_done bytes="; LLen(scan%())
