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

$script = @'
set -euo pipefail

get_value() {
  local key="$1"
  printf '%s\n' "$toolchain_info" | sed -n "s/^${key}=//p" | head -1
}

toolchain_info="$(bash scripts/find-wsl-toolchain.sh)"
cc="$(get_value LUCKFOX_CC)"
sysroot="$(get_value LUCKFOX_SYSROOT)"

if [[ -z "$cc" || -z "$sysroot" ]]; then
  echo "Could not resolve Luckfox compiler and sysroot." >&2
  exit 1
fi

mkdir -p build/tools
"$cc" \
  --sysroot="$sysroot" \
  -std=c11 \
  -O2 \
  -Wall \
  -Wextra \
  -Werror \
  -o build/tools/picocalc-fbdev-harness \
  tools/picocalc_fbdev_harness.c

file build/tools/picocalc-fbdev-harness
'@

$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
wsl.exe -d Ubuntu-22.04 -- bash -lc "cd '$wslRepo' && echo '$encoded' | base64 -d | bash"
if ($LASTEXITCODE -ne 0) {
  throw "fbdev harness build failed with exit code $LASTEXITCODE"
}

Write-Output "Built: $repoRoot\build\tools\picocalc-fbdev-harness"
