param(
  [string]$Adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
  [ValidateSet('all', 'buggy-order', 'fixed-nosync', 'fixed-msync', 'fixed-pwrite', 'text-layering')]
  [string]$Case = 'all',
  [int]$HoldMs = 750,
  [string]$RemotePath = '/tmp/picocalc-fbdev-harness'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Adb)) {
  throw "adb not found: $Adb"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$binary = Join-Path $repoRoot 'build\tools\picocalc-fbdev-harness'
if (-not (Test-Path -LiteralPath $binary)) {
  & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build-picocalc-fbdev-harness.ps1')
}
if (-not (Test-Path -LiteralPath $binary)) {
  throw "fbdev harness binary not found after build: $binary"
}

& $Adb push $binary $RemotePath | Write-Output
& $Adb shell "chmod 755 '$RemotePath'"

$remoteCommand = "'$RemotePath' --case '$Case' --hold-ms '$HoldMs'"
& $Adb shell $remoteCommand
$runExit = $LASTEXITCODE

# Repaint the physical console after framebuffer tests, including failing runs.
# The ili9488 panel can retain a tiny physical right/bottom edge outside the
# 320x320 fbdev image. A black clear plus fb0 blank/unblank resets that stale
# panel state before the console prompt is restored.
$cleanupScript = @"
#!/bin/sh
python3 - <<'PY'
from pathlib import Path
fb = Path('/dev/fb0')
stride = int(Path('/sys/class/graphics/fb0/stride').read_text())
row = bytes(stride)
with fb.open('r+b', buffering=0) as handle:
    for _ in range(320):
        handle.write(row)
PY
if [ -w /sys/class/graphics/fb0/blank ]; then
  echo 1 > /sys/class/graphics/fb0/blank
  sleep 0.2
  echo 0 > /sys/class/graphics/fb0/blank
fi
printf '\033[2J\033[Hfbdev harness finished: $Case\r\n' > /dev/tty0
"@
$cleanupPath = Join-Path $env:TEMP 'picocalc-fbdev-harness-cleanup.sh'
[System.IO.File]::WriteAllText($cleanupPath, $cleanupScript, [System.Text.UTF8Encoding]::new($false))
& $Adb push $cleanupPath /tmp/picocalc-fbdev-harness-cleanup.sh | Out-Null
& $Adb shell "chmod 755 /tmp/picocalc-fbdev-harness-cleanup.sh; /tmp/picocalc-fbdev-harness-cleanup.sh" | Out-Null

if ($runExit -ne 0) {
  throw "fbdev harness failed with exit code $runExit"
}
