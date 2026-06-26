param(
  [int]$HoldSeconds = 15
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Get-DevRepoRoot
$holdMs = [Math]::Max(1, $HoldSeconds) * 1000
$basicTemplate = @'
Option Explicit
Dim Integer i%
CLS
Print "TOP LINE AFTER CLS"
Pause 1500
Print Chr$(27) + "[2J";
Print "VT100 CLEAR OK"
Pause 1500
CLS
For i% = 1 To 40
  Print @(0, 0) "MENU HOLDS AT TOP"
  Print @(0, MM.FONTHEIGHT) "PRINT @ REDRAW TEST"
Next i%
Print @(0, MM.FONTHEIGHT * 3) "TEXT SHOULD NOT SCROLL"
Pause __HOLD_MS__
CLS
Print "VISUAL DONE"
Pause 3000
End
'@
$basic = $basicTemplate.Replace('__HOLD_MS__', [string]$holdMs)

$temp = Join-Path ([System.IO.Path]::GetTempPath()) 'picocalc-text-visual.bas'
[System.IO.File]::WriteAllText($temp, $basic.Replace("`r`n", "`n"))

Invoke-DevCommand -FilePath 'adb' -ArgumentList @('push', $temp, '/tmp/picocalc-text-visual.bas') -WorkingDirectory $repoRoot
Invoke-DevCommand -FilePath 'adb' -ArgumentList @(
  'shell',
  'MMB4L_PICOCALC_CONSOLE=screen mmbasic /tmp/picocalc-text-visual.bas; rc=$?; echo visual_rc:$rc; exit $rc'
) -WorkingDirectory $repoRoot

Write-Output 'Ask the screen observer to confirm: top-line text, VT100 clear text, and PRINT @ menu text did not scroll away.'
