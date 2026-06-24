' tst_picocalc_option_wifi_readonly.bas -- OPTION WIFI read-only Linux compatibility.
Option Explicit

Dim ssid$ = MM.INFO$(ENVVAR "MMB4L_TEST_WIFI_SSID")
If ssid$ = "" Then
  Print "picocalc_option_wifi_readonly: NO ASSERTIONS - set MMB4L_TEST_WIFI_SSID to the connected Linux SSID"
  End
EndIf

OPTION WIFI ssid$, ""
Print "option_wifi_readonly_done"
