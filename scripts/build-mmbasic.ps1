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

wsl.exe -d Ubuntu-22.04 -- bash -lc "cd '$wslRepo' && bash scripts/build-mmbasic-wsl.sh"
if ($LASTEXITCODE -ne 0) {
  throw "WSL MMBasic build failed with exit code $LASTEXITCODE"
}
