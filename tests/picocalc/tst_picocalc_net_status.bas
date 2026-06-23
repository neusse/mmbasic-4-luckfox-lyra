' tst_picocalc_net_status.bas -- WebMite-style read-only network status on Luckfox.
Option Explicit
Print "net_status_start"

Dim ip$ = MM.INFO$(IP ADDRESS)
Dim wifi% = MM.INFO(WIFI STATUS)
Dim tcpip% = MM.INFO(TCPIP STATUS)

Print "ip="; ip$
Print "wifi_status="; wifi%
Print "tcpip_status="; tcpip%

If Len(ip$) < 7 Then Error "bad ip string"
If InStr(ip$, ".") = 0 Then Error "ip string missing dot"
If wifi% < -3 Or wifi% > 1 Then Error "wifi status range"
If tcpip% < -3 Or tcpip% > 3 Then Error "tcpip status range"
If ip$ <> "0.0.0.0" And tcpip% <> 3 Then Error "ip without tcpip status"
If tcpip% = 3 And ip$ = "0.0.0.0" Then Error "tcpip status without ip"

Print "net_status_done"
