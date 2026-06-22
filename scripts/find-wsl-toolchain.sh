#!/usr/bin/env bash
set -euo pipefail

candidate_sdks=()

if [[ -n "${LUCKFOX_SDK_DIR:-}" ]]; then
  candidate_sdks+=("$LUCKFOX_SDK_DIR")
fi

candidate_sdks+=(
  "$HOME/luckfox-lyra-build/picocalc-luckfox-lyra/SDK"
)

shopt -s nullglob
for archived_sdk in "$HOME"/luckfox-lyra-archive/*/luckfox-lyra-build/picocalc-luckfox-lyra/SDK; do
  candidate_sdks+=("$archived_sdk")
done
shopt -u nullglob

for sdk in "${candidate_sdks[@]}"; do
  host_dir="$sdk/buildroot/output/rockchip_rk3506_picocalc_luckfox/host"
  cc="$host_dir/bin/arm-buildroot-linux-gnueabihf-gcc"
  cxx="$host_dir/bin/arm-buildroot-linux-gnueabihf-g++"
  sysroot="$host_dir/arm-buildroot-linux-gnueabihf/sysroot"

  if [[ -x "$cc" && -d "$sysroot" ]]; then
    cat <<EOF
LUCKFOX_TOOLCHAIN_KIND=buildroot-host
LUCKFOX_SDK_DIR=$sdk
LUCKFOX_HOST_DIR=$host_dir
LUCKFOX_CC=$cc
LUCKFOX_CXX=$cxx
LUCKFOX_SYSROOT=$sysroot
LUCKFOX_TARGET=$( "$cc" -dumpmachine )
LUCKFOX_GCC_VERSION=$( "$cc" --version | head -1 )
EOF
    exit 0
  fi
done

for root in "$HOME/luckfox-lyra-build" "$HOME/luckfox-lyra-archive"; do
  [[ -d "$root" ]] || continue
  cc="$(find "$root" -type f -path '*/buildroot/output/*/host/bin/arm-buildroot-linux-gnueabihf-gcc' -print -quit 2>/dev/null || true)"
  [[ -n "$cc" ]] || continue

  host_dir="$(cd "$(dirname "$cc")/.." && pwd)"
  sysroot="$host_dir/arm-buildroot-linux-gnueabihf/sysroot"
  sdk="${host_dir%%/buildroot/output/*}"
  cxx="$host_dir/bin/arm-buildroot-linux-gnueabihf-g++"

  if [[ -d "$sysroot" ]]; then
    cat <<EOF
LUCKFOX_TOOLCHAIN_KIND=buildroot-host
LUCKFOX_SDK_DIR=$sdk
LUCKFOX_HOST_DIR=$host_dir
LUCKFOX_CC=$cc
LUCKFOX_CXX=$cxx
LUCKFOX_SYSROOT=$sysroot
LUCKFOX_TARGET=$( "$cc" -dumpmachine )
LUCKFOX_GCC_VERSION=$( "$cc" --version | head -1 )
EOF
    exit 0
  fi
done

echo "No Luckfox Buildroot userland toolchain found." >&2
echo "Set LUCKFOX_SDK_DIR to the SDK path or build the Luckfox SDK first." >&2
exit 1
