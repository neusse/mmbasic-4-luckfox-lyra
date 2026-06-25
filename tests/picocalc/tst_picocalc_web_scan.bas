' tst_picocalc_web_scan.bas -- WebMite WEB SCAN smoke test on Luckfox.
Option Explicit
Print "web_scan_start"
If MM.INFO(WIFI STATUS) = 0 Then
  Print "picocalc_web_scan: NO ASSERTIONS - Wi-Fi interface is not available"
  End
EndIf
WEB SCAN
Print "web_scan_done"
