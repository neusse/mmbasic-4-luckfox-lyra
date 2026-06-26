param(
  [string]$Adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
  [string]$LocalPng = "$env:TEMP\picocalc-captures\mmbasic-text-cls.png",
  [string]$ScreenshotModule = '/home/neusse/luckfox-dev/python/picofb/screenshot.py',
  [string]$ScreenshotPythonPath = '/home/neusse/luckfox-dev/python',
  [int]$MinimumNonBlackPixels = 20
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Adb)) {
  throw "adb not found: $Adb"
}

$localPngPath = [System.IO.Path]::GetFullPath($LocalPng)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $localPngPath) | Out-Null

$remoteBasic = '/tmp/mmbasic-text-cls.bas'
$remotePng = '/tmp/mmbasic-text-cls.png'
$remoteLog = '/tmp/mmbasic-text-cls.log'
$remoteRc = '/tmp/mmbasic-text-cls.rc'
$remoteShotLog = '/tmp/mmbasic-text-cls-shot.log'
$remoteScript = '/tmp/verify-mmbasic-text-cls.sh'

$script = @"
#!/bin/sh
set -eu
cat > '$remoteBasic' <<'BASIC'
CLS
PRINT "CLS TEXT MODE"
PAUSE 3000
BASIC
rm -f '$remotePng' '$remoteLog' '$remoteRc' '$remoteShotLog'
export MMB4L_PICOCALC_CONSOLE=screen
(mmbasic '$remoteBasic' < /dev/tty0 > /dev/tty0 2> '$remoteLog'; echo `$? > '$remoteRc') &
pid=`$!
sleep 1
PYTHONPATH='$ScreenshotPythonPath' python3 '$ScreenshotModule' '$remotePng' > '$remoteShotLog' 2>&1
wait `$pid || true
echo mmbasic_rc:`$(cat '$remoteRc')
cat '$remoteLog'
cat '$remoteShotLog'
"@

$tempScript = Join-Path $env:TEMP 'verify-mmbasic-text-cls.sh'
[System.IO.File]::WriteAllText($tempScript, $script, [System.Text.UTF8Encoding]::new($false))

& $Adb push $tempScript $remoteScript | Write-Output
& $Adb shell "chmod 755 '$remoteScript'; '$remoteScript'" | Tee-Object -Variable remoteOutput
& $Adb pull $remotePng $localPngPath | Write-Output

$rcLine = $remoteOutput | Where-Object { $_ -like 'mmbasic_rc:*' } | Select-Object -Last 1
if ($rcLine -ne 'mmbasic_rc:0') {
  throw "Text CLS BASIC test failed: $rcLine"
}

Add-Type -AssemblyName System.Drawing
$bitmap = [System.Drawing.Bitmap]::new($localPngPath)
try {
  if ($bitmap.Width -ne 320 -or $bitmap.Height -ne 320) {
    throw "Expected 320x320 capture, got $($bitmap.Width)x$($bitmap.Height)"
  }

  $nonBlack = 0
  for ($y = 0; $y -lt $bitmap.Height; $y++) {
    for ($x = 0; $x -lt $bitmap.Width; $x++) {
      $pixel = $bitmap.GetPixel($x, $y)
      if (($pixel.R + $pixel.G + $pixel.B) -gt 30) {
        $nonBlack++
      }
    }
  }

  if ($nonBlack -lt $MinimumNonBlackPixels) {
    throw "Expected console text after CLS, but capture only had $nonBlack non-black pixels"
  }
} finally {
  $bitmap.Dispose()
}

Write-Output "Text CLS console capture verified: $localPngPath"
