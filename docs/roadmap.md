# Roadmap

This roadmap keeps the public work focused on MMB4L for the Luckfox Lyra
PicoCalc. PicoMite firmware sources are reference material only; they are not
part of this project.

## Status Summary

The initial bring-up is complete:

- Upstream MMB4L is tracked as the `mmb4l/` submodule.
- Luckfox/PicoCalc changes are applied as patches from `patches/mmb4l/`.
- The ARMv7 hard-float build runs on the Luckfox PicoCalc.
- The release bundle includes a compiled `mmbasic`, installer, tests,
  `mmb4l-run-tests`, `mmb4l-check-basic`, DirectFB config, and checksums.
- SDL2/DirectFB graphics work on the PicoCalc framebuffer for the current
  supported console/text-mode target.
- CSUB execution and `MM.INFO(CALLTABLE)` work for the current ARM Luckfox
  build, with documented call-table limitations.
- Linux-owned WiFi status, WiFi scan, read-only `OPTION WIFI`, no-op
  `WEB NTP`, and outbound HTTP/HTTPS REST calls are implemented.

## Supported Target Policy

The supported target is the Luckfox Lyra PicoCalc running in normal Linux
console/text mode, or launched over SSH/ADB while using the PicoCalc
framebuffer. GUI/X11 desktop use is not the primary support path and may vary
by framebuffer ownership, DirectFB behavior, keyboard routing, and permissions.

Linux owns WiFi association, DHCP, routing, TLS certificates, and system time.
MMBasic should inspect network state and provide program network IO, but it
should not reconfigure Linux networking.

## Milestone 1: Input Reliability

Goal: make PicoCalc keyboard behavior reliable in graphics and console use.

Tasks:

- Add or improve direct evdev input from `/dev/input/event0` or the stable
  by-path keyboard device.
- Map arrows, function keys, escape, enter, backspace/delete, modifiers, and
  break behavior into MMBasic consistently.
- Preserve normal terminal input for SSH and ADB sessions.
- Add a target smoke test that can inspect key delivery without hanging.

## Milestone 2: Graphics Completion And Regression Coverage

Goal: keep moving from "graphics works" to "real BASIC programs stay correct."

Tasks:

- Continue testing real programs that mix `CLS`, `PRINT`, `PRINT @`, `TEXT`,
  sprites, pages, framebuffer commands, and images.
- Add visual regression programs and captured expected screenshots where useful.
- Keep the DirectFB setup documented and packaged.
- Decide whether SDL2/DirectFB remains the long-term backend or whether a
  native `/dev/fb0` RGB565 backend is justified.

## Milestone 3: Audio

Goal: replace compatibility no-op behavior with real sound where practical.

Tasks:

- Verify SDL audio over ALSA on the `picocalcsndpwm` device.
- Route `BEEP`, `PLAY SOUND`, and related sound commands through working audio
  if SDL/ALSA is reliable.
- Add a direct ALSA backend only if SDL audio blocks progress.
- Keep no-audio compatibility documented for programs that can continue without
  sound.

## Milestone 4: Inbound Web Server

Goal: implement the useful WebMite-style inbound HTTP/TCP surface on Linux.

Tasks:

- Add `OPTION TCP SERVER PORT`.
- Add `OPTION WEB MESSAGES`.
- Add a nonblocking Linux TCP listener.
- Add `WEB TCP INTERRUPT`.
- Add `WEB TCP READ`, `WEB TCP SEND`, and `WEB TCP CLOSE`.
- Add `WEB TRANSMIT PAGE` and `WEB TRANSMIT FILE`.

Telnet, TFTP, UDP, MQTT, and AP-mode WiFi management remain out of scope unless
a real program need changes that decision.

## Milestone 5: Hardware IO Safety Map

Goal: define what can be safely exposed before adding real GPIO/I2C/SPI.

Tasks:

- Create `docs/picocalc-pin-map.md`.
- Classify pins and buses as reserved or safe for user IO.
- Identify display, keyboard, power, storage, boot, and other critical lines.
- Choose GPIO backend policy: `libgpiod` first, sysfs only as fallback.
- Verify `/dev/i2c-0` and any SPI devices before exposing them to BASIC.

## Milestone 6: Linux-Backed Hardware IO

Goal: implement hardware commands only after the safety map is complete.

Tasks:

- Add Linux-backed GPIO for safe pins.
- Add I2C only for safe exposed buses.
- Add SPI only if the bus is not shared with display or system-critical
  devices.
- Return clear platform errors for unsafe or unavailable hardware.

## Milestone 7: Remaining PicoMite/WebMite Language Compatibility

Goal: add high-value manual-backed compatibility without exhausting function
token space.

Command-table candidates:

- `/*`
- `*/`
- `CHAIN`
- `LMID`
- `BIT` assignment
- `BYTE` assignment
- `FLAG` assignment

Function-token candidates requiring token-budget review:

- `BIT(`
- `BYTE(`
- `FLAG(`
- `TRIM$(`

Deferred candidate:

- Regex support for `INSTR` and `LINSTR`.

## Supporting Work

- Keep `mmb4l-check-basic` useful for real SD card BASIC programs.
- Keep `mmb4l-run-tests` reporting success, failure, skip, and no-assertion
  cases clearly.
- Keep release bundles installable without a build.
- Keep the patch queue documented patch by patch.
- Revisit a source fork only if the patch queue becomes too large to maintain
  cleanly as patches over upstream MMB4L.
