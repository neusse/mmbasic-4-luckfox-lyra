#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

get_value() {
  local key="$1"
  printf '%s\n' "$toolchain_info" | sed -n "s/^${key}=//p" | head -1
}

toolchain_info="$(bash scripts/find-wsl-toolchain.sh)"
cc="$(get_value LUCKFOX_CC)"
sysroot="$(get_value LUCKFOX_SYSROOT)"

if [[ -z "$cc" || -z "$sysroot" ]]; then
  echo "Could not resolve Luckfox compiler/sysroot." >&2
  exit 1
fi

mkdir -p artifacts

printf 'int main(void){return 42;}\n' |
  "$cc" --sysroot="$sysroot" -O2 -xc - -o artifacts/armhf-probe

file artifacts/armhf-probe
