$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$binary = Join-Path $repoRoot 'build\mmb4l-luckfox-release\mmbasic'

if (-not (Test-Path -LiteralPath $binary)) {
  throw "MMBasic binary not found at $binary. Run scripts\build-mmbasic.ps1 first."
}

$adb = Get-Command adb -ErrorAction SilentlyContinue
$knownAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$adbPath = if ($adb) { $adb.Source } elseif (Test-Path -LiteralPath $knownAdb) { $knownAdb } else { '' }

if (-not $adbPath) {
  throw 'adb.exe was not found. See docs/setup/windows-adb.md.'
}

& $adbPath push $binary /tmp/mmbasic

$tempBas = Join-Path ([System.IO.Path]::GetTempPath()) 'mmb4l-smoke.bas'
[System.IO.File]::WriteAllText($tempBas, "PRINT `"hello from mmbasic on picocalc`"`nPRINT 6*7`nEND`n")

try {
  & $adbPath push $tempBas /tmp/hello.bas
  & $adbPath shell 'chmod 755 /tmp/mmbasic; /tmp/mmbasic --help; /tmp/mmbasic --version; /tmp/mmbasic /tmp/hello.bas; echo smoke_exit:$?; rm -f /tmp/hello.bas /tmp/mmbasic'
} finally {
  Remove-Item -LiteralPath $tempBas -Force -ErrorAction SilentlyContinue
}
