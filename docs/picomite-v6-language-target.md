# PicoMite V6 Language Target For Luckfox MMB4L

This project uses upstream MMB4L as the base interpreter for Luckfox/PicoCalc. PicoMite/WebMite V6 is the compatibility target for additional commands and functions. Because PicoMite already runs on the PicoCalc, the default assumption is that documented PicoMite/WebMite V6 behavior is needed unless it is proven impossible or unsafe on the Luckfox/Linux hardware path.

## Source Manuals

- `C:\Users\georg\Codex_Projects\mmbasic-4-luckfox-lyra\MMBasic DOS Version Manual.pdf`
  - MMBasic DOS/Windows Version User Manual
  - MMBasic Ver 5.05.05
- `C:\Users\georg\Codex_Projects\mmbasic-4-luckfox-lyra\PicoMite_User_Manual.pdf`
  - PicoMite User Manual
  - MMBasic Ver 6.02.01
  - Revision 2, 10 May 2026

Extracted comparison files are in:

- `C:\Users\georg\Codex_Projects\mmbasic-4-luckfox-lyra\tmp\manual-compare`

## Working Rules

- MMB4L remains the base.
- The PicoMite/WebMite V6 manual is the target language reference.
- `mmb4l-language-v6` is reference implementation code only. Do not merge or cherry-pick it wholesale.
- The active gap list is only the gap from current Luckfox MMB4L to the loaded PicoMite/WebMite V6 manual language documentation.
- Do not add a one-byte function token unless the feature is documented here with decision `keep`.
- Prefer command-table additions before function-token additions because command tokens do not consume the scarce one-byte function table.
- Linux platform work should adapt the PicoMite feature to Luckfox/PicoCalc, not reclassify it away. A feature can be blocked by a missing backend, unsafe pin ownership, or token-table architecture, but it stays in the target gap unless it is proven not applicable.
- WiFi and graphics are in scope. GPIO, I2C, SPI, and other IO are in scope after display/input are stable and the PicoCalc pin/bus safety map is proven.

## Initial Feature Decisions

| Feature | Kind | Manual Source | Current Luckfox Status | Token Cost | Backend Needed | Decision |
| --- | --- | --- | --- | --- | --- | --- |
| `PIXEL` | Command | PicoMite V6, drawing commands | Present | command table only | graphics display | keep |
| `PIXEL(` | Function | PicoMite V6, graphics functions | Present | one function token | verified PicoCalc auto-display | keep |
| `TEXT` | Command | PicoMite V6, drawing commands | Present | command table only | graphics display | keep |
| `RGB(` | Function | PicoMite V6, graphics functions | Present | already spent | none | keep |
| `MM.HRES` | Function/info | PicoMite V6 behavior, graphics examples | Present | already spent | display mode dimensions | keep |
| `MM.VRES` | Function/info | PicoMite V6 behavior, graphics examples | Present | already spent | display mode dimensions | keep |
| `INKEY$` | Function | DOS V5 and PicoMite V6 | Present | already spent | console/evdev input | keep |
| `/*` | Command | PicoMite V6 commands | Missing | command table only | none | keep |
| `*/` | Command | PicoMite V6 commands | Missing | command table only | none | keep |
| `CHAIN` | Command | PicoMite V6 commands | Missing | command table only | filesystem/run semantics | keep |
| `LMID` | Command | PicoMite V6 long string commands | Missing | command table only | long string support | keep |
| `BLIT MEMORY` | Command | PicoMite V6 BLIT commands | Present | command table only | verified PicoCalc auto-display | keep |
| `BIT` assignment | Command form | PicoMite V6 commands | Missing | command table only | integer variable mutation | keep |
| `BYTE` assignment | Command form | PicoMite V6 commands | Missing | command table only | string byte mutation | keep |
| `FLAG` assignment | Command form | PicoMite V6 commands | Missing | command table only | system flag register | keep, implement PicoMite-compatible semantics |
| `BIT(` | Function | PicoMite V6 functions | Missing | one function token | integer bit readback | keep, gated by token budget |
| `BYTE(` | Function | PicoMite V6 functions | Missing | one function token | string byte readback | keep, gated by token budget |
| `FLAG(` | Function | PicoMite V6 functions | Missing | one function token | system flag register | keep, gated by token budget |
| `TRIM$(` | Function | PicoMite V6 functions | Missing | one function token | none | keep, gated by token budget |
| `SAVE IMAGE` | Command | PicoMite V6, Load and Save Image | Present | command table only | verified PicoCalc auto-display/readback | keep |

## Immediate Implementation Focus

Graphics is the first required platform milestone. The Mandelbrot demo uses existing language features:

- `MM.HRES`
- `MM.VRES`
- `RGB(`
- `PIXEL`
- `TEXT`
- `INKEY$`

Therefore the first practical milestone is making the existing graphics and keyboard path work correctly on the Luckfox/PicoCalc display. That acceptance path proves the display, framebuffer, colour, text, and keyboard stack so the remaining manual-backed graphics surface has a working platform underneath it.

Current graphics status:

- PicoCalc auto-display works for `MM.HRES`, `MM.VRES`, `PIXEL`, `PIXEL(`, `LINE`, `BOX`, `TEXT`, `CLS RGB(...)`, `ARC`, `CIRCLE`, `RBOX`, `TRIANGLE`, `POLYGON`, default `BLIT`, `BLIT READ`, `BLIT WRITE`, `BLIT MEMORY`, `BLIT COMPRESSED`, `LOAD BMP`, `LOAD IMAGE`, `LOAD PNG`, `SAVE IMAGE`, `IMAGE RESIZE`, `IMAGE RESIZE FAST`, `IMAGE ROTATE`, `IMAGE ROTATE FAST`, and basic `SPRITE LOAD` / `SPRITE READ` / `SPRITE SHOW` / `SPRITE NEXT` / `SPRITE MOVE` / `SPRITE HIDE` / `SPRITE MEMORY` / `SPRITE COMPRESSED`.
- Explicit `GRAPHICS WINDOW 0, 320, 320, ... , 1` on PicoCalc should use the full 320x320 framebuffer instead of the desktop 85% fit rule. The window path now probes the PicoCalc framebuffer, uses scale 1, positions exact framebuffer windows at `(0,0)` when x/y are omitted, and asks SDL for a borderless window.
- `IMAGE WARP_H` and `IMAGE WARP_V` are deferred because they were not found in the loaded PicoMite V6 manual text or extracted PicoMite command lists.
- DirectFB VT takeover/disallocation warnings are avoided by installing `scripts/target/directfbrc` to `/etc/directfbrc` with `no-vt` and `no-vt-switch`. The DirectFB deinitialization warning is fixed by calling `graphics_term()` and `events_term()` on the non-interactive interpreter exit path. DirectFB still emits gamma-ramp and `fusion_*` backend messages on this platform.

## CSUB Status

Luckfox ARM builds support `MM.INFO(CALLTABLE)` and CSUB dispatch through `patches/mmb4l/0010-luckfox-csub-calltable-runtime.patch`.

Verified:

- `MM.INFO(CALLTABLE)` returns a nonzero table address.
- A Thumb CSUB can execute from MMB4L program memory and mutate a BASIC integer argument.
- User-provided `bubblerow` CSUB has been tested on the PicoCalc by the user and runs without error.

Known limitations:

- The call table is not a complete PicoMite hardware ABI yet. Core memory, temporary memory, free-memory, math/float helpers, and basic drawing wrappers exist, but unsupported hardware entries intentionally throw an error.
- GPIO-related call-table entries are placeholders until the PicoCalc/Luckfox pin and bus safety map is complete.
- Audio, PIO, low-level display buffers, and reset/execute-program style entries are not yet mapped to Linux equivalents.
- CSUB support is enabled for ARM Luckfox builds only; it is not treated as a general desktop MMB4L feature.
