param(
  [string]$Adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
  [string]$LocalPng = "$env:TEMP\picocalc-captures\mmbasic-framebuffer-capture.png",
  [string]$RemoteDir = '/tmp/picocalc-tests/picocalc',
  [string]$ScreenshotModule = '/home/neusse/luckfox-dev/python/picofb/screenshot.py',
  [string]$ScreenshotPythonPath = '/home/neusse/luckfox-dev/python'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Adb)) {
  throw "adb not found: $Adb"
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$basic = Join-Path $repoRoot 'tests\picocalc\tst_picocalc_gfx_framebuffer_capture.bas'
if (-not (Test-Path -LiteralPath $basic)) {
  throw "Required BASIC test not found: $basic"
}

$localPngPath = [System.IO.Path]::GetFullPath($LocalPng)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $localPngPath) | Out-Null

$remoteBasic = "$RemoteDir/tst_picocalc_gfx_framebuffer_capture.bas"
$remotePng = '/tmp/mmbasic-framebuffer-capture.png'
$remoteLog = '/tmp/mmbasic-framebuffer-test.log'
$remoteRc = '/tmp/mmbasic-framebuffer-test.rc'
$remoteShotLog = '/tmp/mmbasic-framebuffer-shot.log'
$remoteScript = '/tmp/verify-mmbasic-framebuffer.sh'

$script = @"
#!/bin/sh
set -eu
rm -f '$remotePng' '$remoteLog' '$remoteRc' '$remoteShotLog'
export SDL_VIDEODRIVER=directfb
export HOME=/root
(mmbasic '$remoteBasic' > '$remoteLog' 2>&1; echo `$? > '$remoteRc') &
pid=`$!
sleep 1
PYTHONPATH='$ScreenshotPythonPath' python3 '$ScreenshotModule' '$remotePng' > '$remoteShotLog' 2>&1
wait `$pid || true
cat '$remoteLog'
echo mmbasic_rc:`$(cat '$remoteRc')
cat '$remoteShotLog'
"@

$tempScript = Join-Path $env:TEMP 'verify-mmbasic-framebuffer.sh'
[System.IO.File]::WriteAllText($tempScript, $script, [System.Text.UTF8Encoding]::new($false))

& $Adb shell "mkdir -p '$RemoteDir'"
& $Adb push $basic $remoteBasic | Write-Output
& $Adb push $tempScript $remoteScript | Write-Output
& $Adb shell "chmod 755 '$remoteScript'; '$remoteScript'" | Tee-Object -Variable remoteOutput
& $Adb pull $remotePng $localPngPath | Write-Output

$rcLine = $remoteOutput | Where-Object { $_ -like 'mmbasic_rc:*' } | Select-Object -Last 1
if ($rcLine -ne 'mmbasic_rc:0') {
  throw "Framebuffer BASIC test failed: $rcLine"
}

Add-Type -AssemblyName System.Drawing
$bitmap = [System.Drawing.Bitmap]::new($localPngPath)
try {
  if ($bitmap.Width -ne 320 -or $bitmap.Height -ne 320) {
    throw "Expected 320x320 capture, got $($bitmap.Width)x$($bitmap.Height)"
  }

  function Assert-ColorNear {
    param(
      [System.Drawing.Bitmap]$Bitmap,
      [int]$X,
      [int]$Y,
      [string]$Name,
      [int]$Red,
      [int]$Green,
      [int]$Blue
    )

    $pixel = $Bitmap.GetPixel($X, $Y)
    $delta = [Math]::Abs($pixel.R - $Red) + [Math]::Abs($pixel.G - $Green) + [Math]::Abs($pixel.B - $Blue)
    if ($delta -gt 48) {
      throw "$Name sample at ($X,$Y) expected near rgb($Red,$Green,$Blue), got rgb($($pixel.R),$($pixel.G),$($pixel.B))"
    }
  }

  Assert-ColorNear $bitmap 40 40 'red quadrant' 255 0 0
  Assert-ColorNear $bitmap 240 40 'green quadrant' 0 255 0
  Assert-ColorNear $bitmap 40 240 'blue quadrant' 0 0 255
  Assert-ColorNear $bitmap 240 240 'white quadrant' 255 255 255
} finally {
  $bitmap.Dispose()
}

Write-Output "Framebuffer capture verified: $localPngPath"
