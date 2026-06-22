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
cxx="$(get_value LUCKFOX_CXX)"
sysroot="$(get_value LUCKFOX_SYSROOT)"
host_dir="$(get_value LUCKFOX_HOST_DIR)"

if [[ -z "$cc" || -z "$cxx" || -z "$sysroot" || -z "$host_dir" ]]; then
  echo "Could not resolve the Luckfox SDK compiler, C++ compiler, host dir, and sysroot." >&2
  exit 1
fi

sdl_include="$sysroot/usr/include/SDL2"
sdl_lib="$sysroot/usr/lib/libSDL2.so"

if [[ ! -f "$sdl_include/SDL.h" ]]; then
  echo "Missing SDL2 headers at: $sdl_include" >&2
  echo "Build the Luckfox SDK with SDL2 development headers in the target sysroot." >&2
  exit 1
fi

if [[ ! -e "$sdl_lib" ]]; then
  echo "Missing SDL2 library at: $sdl_lib" >&2
  echo "Build the Luckfox SDK with SDL2 in the target sysroot." >&2
  exit 1
fi

source_dir="${SOURCE_DIR:-$repo_root/build/mmb4l-luckfox-source}"
build_dir="${BUILD_DIR:-$repo_root/build/mmb4l-luckfox-release}"
toolchain_file="$build_dir/luckfox-toolchain.cmake"

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required to create the patched build source tree." >&2
  exit 1
fi

rsync -a --delete \
  --exclude .git \
  --exclude build \
  "$repo_root/mmb4l/" "$source_dir/"

# Windows checkouts may have CRLF line endings. Normalize the generated build
# copy so portable patches apply without modifying the upstream submodule.
find "$source_dir" \
  \( -name 'CMakeLists.txt' -o -name '*.cmake' -o -name '*.c' -o -name '*.h' -o -name '*.cxx' -o -name '*.hxx' -o -name '*.bas' -o -name '*.inc' \) \
  -type f -exec perl -pi -e 's/\r$//' {} +

shopt -s nullglob
for patch_file in "$repo_root"/patches/mmb4l/*.patch; do
  echo "Applying patch: ${patch_file#$repo_root/}"
  (cd "$source_dir" && patch -p1 --forward < "$patch_file")
done
shopt -u nullglob

rm -rf "$build_dir"
mkdir -p "$build_dir"

cat > "$toolchain_file" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER "$cc")
set(CMAKE_CXX_COMPILER "$cxx")
set(CMAKE_SYSROOT "$sysroot")
set(CMAKE_FIND_ROOT_PATH "$sysroot" "$host_dir")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF

cmake \
  -S "$source_dir" \
  -B "$build_dir" \
  -DCMAKE_TOOLCHAIN_FILE="$toolchain_file" \
  -DCMAKE_BUILD_TYPE=Release \
  -DMMB4L_SDL2_INCLUDE_DIR="$sdl_include" \
  -DMMB4L_SDL2_LIBRARY="$sdl_lib" \
  -DCMAKE_C_FLAGS="-I$sdl_include" \
  -DCMAKE_CXX_FLAGS="-I$sdl_include" \
  -DCMAKE_EXE_LINKER_FLAGS="-L$sysroot/usr/lib -Wl,-rpath-link,$sysroot/usr/lib -Wl,-rpath-link,$sysroot/lib"

cmake --build "$build_dir" --target mmbasic --parallel "${JOBS:-4}"

file "$build_dir/mmbasic"

echo "Built: $build_dir/mmbasic"
