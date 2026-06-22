# Roadmap

This roadmap keeps the public work focused on MMB4L for the Luckfox Lyra
PicoCalc. PicoMite firmware sources are not part of this project.

## Milestone 0: Repeatable Host Setup

Status: mostly complete.

- Root repository initialized for publication.
- Upstream MMB4L registered as the `mmb4l/` submodule.
- Upstream sptools initialized through MMB4L.
- Windows ADB path documented and verified.
- Luckfox SDK Buildroot userland compiler discovered from WSL.
- ARM hard-float ABI probe built, pushed over ADB, and verified with
  `probe_exit:42`.
- MMB4L `mmbasic` cross-built, pushed over ADB, and verified with a small BASIC
  program returning `smoke_exit:0`.

## Milestone 1: Stock MMB4L Cross Build

Status: complete for a first CLI binary.

Goal: build the upstream MMB4L source for the Luckfox Buildroot target with no
upstream submodule edits.

Tasks:

- Use the CMake/toolchain build path in `scripts/build-mmbasic-wsl.sh`:
  - `arm-buildroot-linux-gnueabihf-gcc`
  - the Luckfox SDK sysroot
  - SDL2 headers and libraries from the SDK sysroot
- Record any MMB4L build assumptions that are desktop-Linux-specific.
- Keep upstream source changes out of `mmb4l/` unless captured as patches under
  `patches/mmb4l/`.
- Push the first `mmbasic` binary to `/tmp/mmbasic` and run a CLI smoke test.

## Milestone 2: Console BASIC Smoke Test

Goal: prove that the interpreter works before tackling graphics and hardware IO.

Tests:

- `PRINT "hello from picocalc"`
- integer and floating-point expressions
- file load/run behavior
- `MM.INFO$()` behavior
- exit/system behavior

## Milestone 3: Graphics Strategy

Goal: decide whether stock SDL2 is enough for the first public build.

Order:

1. Try SDL2/DirectFB because the target image has SDL2 runtime libraries.
2. Verify whether MMB4L graphics can own the 320x320 framebuffer cleanly.
3. Add a native `/dev/fb0` RGB565 backend only if SDL2 blocks progress.

## Milestone 4: PicoCalc Input

Goal: support the built-in keyboard correctly.

Options:

- Use normal terminal input for the console-first milestone.
- Add direct evdev input from `/dev/input/event0` for handheld graphics mode.

## Milestone 5: Audio

Goal: verify sound through the target ALSA device.

Order:

1. Try MMB4L SDL audio over ALSA.
2. Add a direct ALSA backend only if SDL audio is not usable.

## Milestone 6: Hardware IO

Goal: expose real PicoCalc/Luckfox hardware safely.

Tasks:

- Define a PicoCalc pin map before adding public BASIC commands.
- Prefer `libgpiod` for GPIO, with sysfs fallback only if required.
- Use `/dev/i2c-0` for I2C experiments.
- Do not expose display or system-critical SPI/GPIO lines as general user IO.
