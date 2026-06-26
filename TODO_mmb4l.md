# TODO: MMB4L For Luckfox Lyra PicoCalc

Date: 2026-06-26

This is the current project TODO. Older bring-up notes have been retired from
this file because the cross-build, package, patch queue, graphics baseline,
CSUB baseline, REST client, checker, and target test runner now exist.

## Current Baseline

- Upstream MMB4L is used as the `mmb4l/` submodule.
- PicoCalc/Luckfox changes are carried as numbered patches in
  `patches/mmb4l/`.
- A prebuilt ARMv7 binary and install-ready release bundles are in `dist/`.
- The release bundle includes `mmbasic`, `mmb4l-run-tests`,
  `mmb4l-check-basic`, DirectFB config, examples, tests, and checksums.
- The supported runtime target is the Luckfox PicoCalc Linux console/text
  environment using the PicoCalc framebuffer. GUI/X11 use is not the primary
  support target and may vary by display stack and input handling.

## Recommended Work Order

1. Finish PicoCalc input reliability.
2. Continue graphics polish using real BASIC programs and visual regression
   tests.
3. Add real audio support or document the final no-audio compatibility policy.
4. Implement the inbound WebMite-style HTTP/TCP server surface.
5. Create the PicoCalc pin and bus safety map.
6. Add safe Linux-backed GPIO, I2C, and SPI only after the pin map is complete.
7. Continue selected PicoMite/WebMite V6 language compatibility work.

## Priority 1: PicoCalc Input

- Add or improve direct evdev input from `/dev/input/event0` or
  `/dev/input/by-path/platform-ff040000.i2c-event-kbd`.
- Map PicoCalc keyboard keys into MMBasic key codes.
- Make graphics-mode `INKEY$`, break handling, arrows, function keys,
  backspace/delete, and enter reliable from the physical PicoCalc console.
- Keep normal terminal input working for SSH and ADB.
- Add a timeout-based target test that logs observed key codes without hanging.

## Priority 2: Graphics Polish

- Keep testing real BASIC programs for `CLS`, `TEXT`, `PRINT @`, sprites,
  framebuffer pages, images, and mixed text/graphics behavior.
- Add more visual regression tests and screenshots for known-good demos.
- Decide whether SDL2/DirectFB remains the long-term display backend.
- Add a native `/dev/fb0` RGB565 backend only if SDL2/DirectFB blocks
  reliability, performance, or console ownership.
- Keep documenting that GUI/X11 is not the primary supported target.

## Priority 3: Audio

- Verify SDL audio over ALSA on the `picocalcsndpwm` card.
- If SDL audio works, route `BEEP`, `PLAY SOUND`, and related commands through
  the normal audio backend.
- If SDL audio is unreliable, add a direct ALSA backend.
- Keep compatibility no-op behavior documented for programs that can run
  without sound.

## Priority 4: Inbound Web Server

Outbound HTTPS REST calls are implemented. The remaining WebMite-style inbound
server surface still needs a Linux socket backend:

- `OPTION TCP SERVER PORT n`
- `OPTION WEB MESSAGES ON|OFF`
- `WEB TCP INTERRUPT sub`
- `WEB TCP READ cb%, buff%()`
- `WEB TCP SEND cb%, data%()`
- `WEB TCP CLOSE cb%`
- `WEB TRANSMIT PAGE cb%, file$`
- `WEB TRANSMIT FILE cb%, file$, content-type$`

Recommended implementation order:

1. Store `OPTION TCP SERVER PORT` and `OPTION WEB MESSAGES`.
2. Add a minimal nonblocking Linux TCP listener.
3. Allocate client handles and bridge accepted clients into BASIC interrupts.
4. Implement raw read, send, and close.
5. Add HTTP file/page helpers.

## Priority 5: Raw TCP Client Compatibility

REST covers the common API case, but raw WebMite TCP client commands remain
separate work:

- `WEB OPEN TCP CLIENT domain$, port`
- `WEB TCP CLIENT REQUEST query$, inbuf [, timeout]`
- `WEB CLOSE TCP CLIENT`
- `WEB OPEN TCP STREAM address$, port`
- `WEB TCP CLIENT STREAM query$, buff%(), r%, w%`

Do this only after the inbound server design is clear, unless a real program
needs raw client compatibility sooner.

## Priority 6: Hardware IO

- Create `docs/picocalc-pin-map.md`.
- Mark pins and buses as `reserved-display`, `reserved-keyboard`,
  `reserved-system`, `safe-user-io`, or `unknown-do-not-use`.
- Do not expose display, keyboard, power, storage, boot, or other critical
  lines as general MMBasic IO.
- Prefer `libgpiod` for GPIO if available in the Luckfox SDK sysroot.
- Use sysfs GPIO only as a fallback.
- Add I2C support through `/dev/i2c-0` only after the bus is proven safe.
- Add SPI support only if user-accessible SPI is isolated from the display and
  other system devices.

## Priority 7: Remaining Language Compatibility

Command-table candidates that do not consume scarce one-byte function tokens:

- `/*`
- `*/`
- `CHAIN`
- `LMID`
- `BIT` assignment
- `BYTE` assignment
- `FLAG` assignment

Function-token candidates that need explicit token-budget review:

- `BIT(`
- `BYTE(`
- `FLAG(`
- `TRIM$(`

Deferred candidate:

- Regex support for `INSTR` and `LINSTR`, documented in
  `docs/future-patches.md`.

## CSUB Follow-Up

- Keep the current ARM Luckfox CSUB runtime.
- Document unsupported call-table entries clearly.
- Add hardware-backed call-table entries only when the matching Linux backend
  exists.
- Do not silently simulate GPIO, audio, PIO, reset, or low-level display
  entries.

## Checker Follow-Up

- Improve include/library awareness.
- Add more known-program compatibility profiles.
- Add optional substitution suggestions for common dialect differences.
- Consider a runtime probe mode for cases static analysis cannot prove.
- Consider a future interpreter-native `mmbasic --check file.bas`.

## Documentation Follow-Up

- Keep `docs/roadmap.md` as the public milestone list.
- Keep `docs/webmite-port-map.md` as the cross-reference from WebMite/PicoMite
  areas to Luckfox implementation status.
- Keep `docs/picomite-v6-language-target.md` focused on manual-backed language
  decisions.
- Keep `docs/luckfox-networking.md` as the source of truth for networking
  policy and implemented WEB commands.
