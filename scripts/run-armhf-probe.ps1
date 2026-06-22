$ErrorActionPreference = 'Stop'

function ConvertTo-WslPath {
  param([string]$WindowsPath)

  $resolved = (Resolve-Path -LiteralPath $WindowsPath).Path
  $drive = $resolved.Substring(0, 1).ToLowerInvariant()
  $rest = $resolved.Substring(2).Replace('\', '/')
  return "/mnt/$drive$rest"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$wslRepo = ConvertTo-WslPath $repoRoot

$adb = Get-Command adb -ErrorAction SilentlyContinue
$knownAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$adbPath = if ($adb) { $adb.Source } elseif (Test-Path -LiteralPath $knownAdb) { $knownAdb } else { '' }

if (-not $adbPath) {
  throw 'adb.exe was not found. See docs/setup/windows-adb.md.'
}

wsl.exe -d Ubuntu-22.04 -- bash -lc "cd '$wslRepo' && bash scripts/build-armhf-probe.sh"

$probePath = Join-Path $repoRoot 'artifacts\armhf-probe'
if (-not (Test-Path -LiteralPath $probePath)) {
  throw "Probe binary was not created at $probePath"
}

& $adbPath push $probePath /tmp/armhf-probe
& $adbPath shell 'chmod 755 /tmp/armhf-probe; /tmp/armhf-probe; echo probe_exit:$?; rm -f /tmp/armhf-probe'
