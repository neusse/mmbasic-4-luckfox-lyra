#!/bin/sh
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")" && pwd)

BIN_DIR=${MMB4L_INSTALL_BIN_DIR:-/usr/local/bin}
PATH_BIN_DIR=${MMB4L_PATH_BIN_DIR:-/usr/bin}
SHARE_DIR=${MMB4L_INSTALL_SHARE_DIR:-/usr/local/share/mmb4l}
DIRECTFB_CONFIG=${MMB4L_DIRECTFB_CONFIG:-/etc/directfbrc}
APPLY_DEVICE_PERMS=${MMB4L_APPLY_DEVICE_PERMS:-1}
RUN_SMOKE=${MMB4L_RUN_SMOKE:-1}

require_file() {
  if [ ! -f "$1" ]; then
    echo "Missing required file: $1" >&2
    exit 1
  fi
}

require_dir() {
  if [ ! -d "$1" ]; then
    echo "Missing required directory: $1" >&2
    exit 1
  fi
}

copy_tree() {
  src=$1
  dst=$2
  require_dir "$src"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
}

require_file "$ROOT/bin/mmbasic"
require_file "$ROOT/bin/mmb4l-run-tests"
require_file "$ROOT/etc/directfbrc"
require_dir "$ROOT/share/examples"
require_dir "$ROOT/share/tests"
require_dir "$ROOT/share/tests/picocalc"
require_dir "$ROOT/share/sptools"

mkdir -p "$BIN_DIR" "$SHARE_DIR"
cp "$ROOT/bin/mmbasic" "$BIN_DIR/mmbasic"
cp "$ROOT/bin/mmb4l-run-tests" "$BIN_DIR/mmb4l-run-tests"
chmod 755 "$BIN_DIR/mmbasic" "$BIN_DIR/mmb4l-run-tests"

copy_tree "$ROOT/share/examples" "$SHARE_DIR/examples"
copy_tree "$ROOT/share/tests" "$SHARE_DIR/tests"
copy_tree "$ROOT/share/sptools" "$SHARE_DIR/sptools"

if [ -n "$DIRECTFB_CONFIG" ]; then
  mkdir -p "$(dirname "$DIRECTFB_CONFIG")"
  cp "$ROOT/etc/directfbrc" "$DIRECTFB_CONFIG"
  chmod 644 "$DIRECTFB_CONFIG"
fi

if [ -n "$PATH_BIN_DIR" ] && [ "$PATH_BIN_DIR" != "$BIN_DIR" ]; then
  mkdir -p "$PATH_BIN_DIR"
  ln -sf "$BIN_DIR/mmbasic" "$PATH_BIN_DIR/mmbasic"
  ln -sf "$BIN_DIR/mmb4l-run-tests" "$PATH_BIN_DIR/mmb4l-run-tests"
fi

if [ "$APPLY_DEVICE_PERMS" = "1" ]; then
  [ -e /dev/fb0 ] && chmod 666 /dev/fb0 || true
  [ -e /dev/tty0 ] && chmod 666 /dev/tty0 || true
fi

echo "Installed mmbasic to $BIN_DIR/mmbasic"
echo "Installed mmb4l-run-tests to $BIN_DIR/mmb4l-run-tests"
echo "Installed MMB4L share files to $SHARE_DIR"
if [ -n "$DIRECTFB_CONFIG" ]; then
  echo "Installed DirectFB config to $DIRECTFB_CONFIG"
fi

if [ "$RUN_SMOKE" = "1" ]; then
  "$BIN_DIR/mmb4l-run-tests" --smoke
fi
