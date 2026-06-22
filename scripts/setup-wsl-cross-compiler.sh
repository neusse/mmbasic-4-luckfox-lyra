#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if "$script_dir/find-wsl-toolchain.sh"; then
  exit 0
fi

if [[ "${1:-}" != "--install-apt-fallback" ]]; then
  cat >&2 <<'EOF'

The preferred Luckfox Buildroot SDK toolchain was not found.

Build or restore the Luckfox SDK first, then set:

  export LUCKFOX_SDK_DIR=/path/to/picocalc-luckfox-lyra/SDK

The generic Ubuntu cross compiler can be installed as a fallback with:

  bash scripts/setup-wsl-cross-compiler.sh --install-apt-fallback

The fallback may not match the target Buildroot sysroot and is not the default.
EOF
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required to install fallback packages" >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y \
  build-essential \
  cmake \
  git \
  pkg-config \
  gcc-arm-linux-gnueabihf \
  g++-arm-linux-gnueabihf \
  libc6-dev-armhf-cross

echo "Fallback compiler: $(command -v arm-linux-gnueabihf-gcc)"
echo "Fallback target: $(arm-linux-gnueabihf-gcc -dumpmachine)"
