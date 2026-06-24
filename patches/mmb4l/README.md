# MMB4L Patch Queue

This directory is for project-specific patches applied on top of upstream
`mmb4l/`.

The build wrapper applies these patches to a generated source copy under
`build/mmb4l-luckfox-source`. It does not patch the `mmb4l/` submodule in
place, so the upstream checkout remains clean and easy to update.

## Current Patches

### `0001-cmake-make-sdl2-paths-configurable.patch`

Purpose: make SDL2 include and library paths configurable from CMake.

Why it is needed: upstream MMB4L defaults to `/usr/include/SDL2` and `SDL2`,
which works for a normal desktop build. The Luckfox SDK compiler rejects
`-I/usr/include/SDL2` during cross-compilation as an unsafe host include path.

What it changes:

- Adds `MMB4L_SDL2_INCLUDE_DIR`.
- Adds `MMB4L_SDL2_LIBRARY`.
- Uses those values for the `mmbasic` target.

Upstream suitability: good candidate. It preserves the existing desktop default
while enabling cross builds.

### `0002-enlarge-trace-line-number-buffer.patch`

Purpose: make trace line-number buffers large enough for `IntToStr()`.

Why it is needed: `IntToStr()` accepts `MMINTEGER`, which is `int64_t`, and its
internal conversion limit is `IntToStrBufSize` (`65`). Two trace paths passed a
`buff[10]` destination. GCC 12 correctly reports this as a possible
`-Wstringop-overflow`, and upstream treats warnings as errors.

What it changes:

- Changes the trace buffer in `src/core/MMBasic.c` from `buff[10]` to
  `buff[STRINGSIZE]`.
- Changes the trace buffer in `src/commands/cmd_trace.c` from `buff[10]` to
  `buff[STRINGSIZE]`.

Upstream suitability: good candidate. This is a real buffer-size correction, not
just a warning suppression.

### `0003-gcc12-allow-drmp3-loop-optimization-warning.patch`

Purpose: allow the bundled third-party MP3 decoder warning under GCC 12 while
keeping upstream's general `-Werror` policy.

Why it is needed: GCC 12 emits `-Waggressive-loop-optimizations` inside bundled
third-party `dr_mp3.h`. The warning is outside our project code and blocks the
cross-build only because all warnings are promoted to errors.

What it changes:

- Adds `-Wno-error=aggressive-loop-optimizations` to the project warning flags.

Upstream suitability: moderate. A cleaner upstream change might scope this flag
only to `dr_audio.c` or update the bundled `dr_mp3.h`, but this patch is small
and keeps all other warnings as errors.

### `0004-harden-basic-tests-for-luckfox-target.patch`

Purpose: make selected upstream BASIC tests meaningful on the Luckfox
Buildroot/BusyBox target.

Why it is needed: the upstream tests include an empty `ATAN3` placeholder,
assume GNU `realpath --relative-to`, assume a developer checkout path under
`$HOME/github`, and run console cursor checks from contexts such as ADB shell
where no interactive console is attached.

What it changes:

- Adds `Math(Atan3 ...)` quadrant assertions.
- Replaces GNU-only `realpath --relative-to` usage with a BASIC relative-path
  helper.
- Uses `Mm.Info(Path)` for the current-file test so installed tests work.
- Skips cursor/terminal-size assertions only when the console query is not
  available.
- Falls back from `PicoMiteVGA` to `Game*Mite` pin-number simulation when the
  target framebuffer cannot allocate the larger VGA surface.

Upstream suitability: good candidate with review. The test changes are mostly
portability improvements, though the installed-layout expectation may need to
be phrased generically for upstream.

### `0005-fix-arm-range-error-formatting.patch`

Purpose: fix range error messages on 32-bit ARM.

Why it is needed: `MMINTEGER` is `int64_t`, but the legacy error formatter reads
`%` placeholders as `int`. Passing `MMINTEGER` values through varargs corrupts
the argument stream on 32-bit ARM and produces messages such as
`0 is invalid (valid is 801 to 0)`.

What it changes:

- Adds `error_throw_int_range()`.
- Uses that helper from `getint()`.

Upstream suitability: good candidate. This fixes a real 32-bit varargs type
mismatch without changing unrelated callers.

### `0006-adapt-tests-for-luckfox-busybox-runtime.patch`

Purpose: adapt test expectations to the Luckfox Buildroot/BusyBox runtime.

Why it is needed: BusyBox shell/coreutils messages differ from GNU desktop
Linux, ADB may run with `HOME=/root`, exact epoch comparisons can cross a
second boundary, and the PicoCalc framebuffer is smaller than some simulated
targets.

What it changes:

- Allows BusyBox `ls` and shell error output.
- Uses the actual `HOME` value reported by MMB4L.
- Allows a two-second tolerance around `Epoch(Now)`.
- Skips display simulation tests on small MMB4L framebuffers.

Upstream suitability: moderate. The time tolerance and shell portability are
good candidates; the framebuffer skip is target-specific.

### `0007-gate-console-and-directfb-test-side-effects.patch`

Purpose: keep console and upstream-all test runs from corrupting the PicoCalc
shell or starting DirectFB unless explicitly requested.

Why it is needed: `Console GetCursor` emits an ANSI cursor-position query
(`ESC[6n`). On the PicoCalc shell, the terminal response can be left for bash
to parse after MMBasic exits. `Option Simulate PicoMiteVGA` can also start
DirectFB, which is noisy over ADB and can fail for non-root console users even
when the test only needs a PicoMite-style pin map.

What it changes:

- Requires `MMB4L_TEST_CURSOR=1` before running `test_hpos` and `test_vpos`.
- Skips display-backed pin-map simulation by default after verifying the native
  MMB4L pin-map error path.
- Allows `MMB4L_TEST_DIRECTFB=1` to exercise the PicoMiteVGA path explicitly.

Upstream suitability: target-specific. This is best kept in the Luckfox wrapper
unless upstream adds a general way to mark tests as interactive or display-owning.

### `0008-report-armv7-linux-architecture.patch`

Purpose: report the actual 32-bit ARM architecture level for Luckfox builds.

Why it is needed: upstream MMB4L labels every `__arm__` Linux build as
`Linux armv6l`. The Luckfox SDK compiler targets ARMv7-A hard-float, so
`mmbasic -v` and `Mm.Info$(Arch)` should report `Linux armv7l`.

What it changes:

- Uses `__ARM_ARCH >= 7` to select `Linux armv7l`.
- Keeps `Linux armv6l` for older 32-bit ARM builds.
- Updates the upstream `tst_mminfo.bas` expectation for `armv7l GNU/Linux`.
- Adds an `mmb4l-armv7l` alias to the `sptools` platform helper.

Upstream suitability: good. This is a general correction for 32-bit ARM Linux
builds that does not require Luckfox-specific paths or runtime assumptions.

### `0009-auto-create-picocalc-display-surface.patch`

Purpose: make PicoCalc graphics work without requiring a desktop-style
`GRAPHICS WINDOW` setup.

Why it is needed: PicoMite programs commonly draw directly with `PIXEL`,
`TEXT`, `LINE`, `BLIT`, image, sprite, and framebuffer commands. On Luckfox,
those commands need an SDL2/DirectFB-backed 320x320 PicoCalc display surface
created automatically when the target framebuffer is detected.

What it changes:

- Auto-creates/selects the PicoCalc display surface for implemented drawing,
  image, BLIT, sprite, and framebuffer commands.
- Adds `FRAMEBUFFER CREATE` / `FRAMEBUFFER WRITE F` compatibility for the
  PicoCalc display surface mapping.
- Adds `MM.INFO(CALLTABLE)` spelling, originally as a placeholder; the runtime
  implementation is supplied by `0010`.
- Adds DirectFB cleanup and PicoCalc display detection helpers.

Upstream suitability: target-specific. The general auto-display idea may be
useful upstream, but this patch includes Luckfox/PicoCalc detection and
DirectFB behavior.

### `0010-luckfox-csub-calltable-runtime.patch`

Purpose: make PicoMite-style CSUBs usable on the Luckfox ARM build.

Why it is needed: CSUBs that receive `MM.INFO(CALLTABLE)` need a real function
pointer table, executable program memory, and a bridge from MMB4L's CSUB blob
format into native ARM Thumb code. Returning `0` for `CALLTABLE` lets BASIC
parse but breaks real CSUBs.

What it changes:

- Enables CSUB dispatch for ARM Luckfox builds.
- Adds a PicoMite-offset-compatible call table for core memory, math/float,
  timer, and basic drawing helpers.
- Uses ARM AAPCS wrappers for float helper entries so PicoMite-style CSUBs can
  call them from hard-float Linux builds.
- Marks the program-memory range executable before CSUB dispatch.
- Returns the real call table address from `MM.INFO(CALLTABLE)`.

Current limitations:

- GPIO, PIO, audio, reset, low-level display-buffer, and execute-program style
  table entries are placeholders until the corresponding Linux/PicoCalc
  backends are designed.
- This is intended for Luckfox ARM builds, not desktop MMB4L.

Upstream suitability: low as-is. It is useful for this target, but general
upstream support would need architecture gates, security review, and a broader
CSUB ABI policy for Linux.

### `0011-picocalc-explicit-window-fullscreen.patch`

Purpose: keep explicit 320x320 PicoCalc graphics windows from being shrunk and
centered by MMB4L's desktop fit rule.

Why it is needed: `graphics_ensure_default_display()` already probes the
PicoCalc framebuffer before creating the auto-display window. But an explicit
`GRAPHICS WINDOW 0, 320, 320, ... , 1` can reach `graphics_window_create()`
before that probe runs. The old desktop rule then limits the window to 85% of
the display and places a smaller square in the center of the PicoCalc screen.

What it changes:

- Probes the PicoCalc framebuffer inside `graphics_window_create()`.
- Allows exact 320x320 scale-1 windows to use the full framebuffer.
- Places omitted x/y exact framebuffer windows at `(0,0)`.
- Requests a borderless SDL window for exact PicoCalc framebuffer windows.

Upstream suitability: target-specific. The broader issue may deserve an
upstream option for full-screen embedded SDL targets.

### `0012-luckfox-network-status.patch`

Purpose: add the first read-only WebMite-style network status surface for the
Luckfox/PicoCalc Linux target.

Why it is needed: WebMite programs can inspect network state from BASIC, but on
Luckfox the operating system should own WiFi configuration. The interpreter
therefore needs a Linux-backed status bridge without trying to manage SSIDs,
passwords, AP mode, DHCP, routing, or time synchronization itself.

What it changes:

- Adds Linux helpers for wireless interface detection, IPv4 status, and WiFi
  scanning.
- Adds `MM.INFO$(IP ADDRESS)` / `MM.INFO(IP ADDRESS)`.
- Adds `MM.INFO(WIFI STATUS)`.
- Adds `MM.INFO(TCPIP STATUS)`.
- Adds `WEB SCAN` as a read-only scan command backed by Linux `iw`.

Current limitations:

- `OPTION WIFI`, `WEB CONNECT` configuration, Telnet, TFTP, NTP, and
  `OPTION WEB MESSAGES` are intentionally not implemented in this slice.
- Program network I/O such as TCP, UDP, HTTP, MQTT, and WebSocket support still
  needs separate Linux socket backends.

Upstream suitability: low as-is. The policy is correct for Luckfox, but the
implementation depends on Linux wireless tooling and should stay target-gated.

### `0013-picocalc-test-display-resolution.patch`

Purpose: make upstream `tst_mminfo.bas` validate the real PicoCalc horizontal
display size.

Why it is needed: the Luckfox PicoCalc target uses the real 320x320 DirectFB
framebuffer. Upstream desktop MMB4L expects terminal character dimensions to
scale into a larger simulated pixel surface, so the unmodified `MM.HRES`
assertions fail even though the PicoCalc behavior is correct.

What it changes:

- Uses `MMB4L_TEST_TARGET=picocalc-luckfox-lyra` from the target runner.
- Asserts `MM.HRES` and `MM.INFO(HRES)` are 320 in both character and pixel
  resolution modes for the PicoCalc target profile.
- Leaves upstream desktop MMB4L expectations unchanged when the target profile
  is not set.

Upstream suitability: low as-is. The assertion is specific to the Luckfox Lyra
PicoCalc build and should remain target-gated.

### `0014-fix-picocalc-mminfo-vres-test.patch`

Purpose: finish the PicoCalc-specific `tst_mminfo.bas` expectations.

Why it is needed: adding target-specific `HRES` assertions changed the
`MM.INFO$(LINE)` line number expected by the same test file. The target also
needs the matching `VRES` assertion for the real 320-pixel framebuffer.

What it changes:

- Updates the MMB4L `MM.INFO$(LINE)` expectation to match the patched source.
- Asserts `MM.VRES` and `MM.INFO(VRES)` are 320 for
  `MMB4L_TEST_TARGET=picocalc-luckfox-lyra`.

Upstream suitability: low as-is. This follows the target-gated test profile
used by the Luckfox PicoCalc runner.

### `0015-accept-picomite-negative-line-width.patch`

Purpose: support PicoMite-compatible negative `LINE` widths.

Why it is needed: PicoMite documents `LINE x1, y1, x2, y2 [,[-] LW [, C]]`;
negative `LW` centers the thickness on the line endpoints and applies to lines
in all directions. MMB4L rejected scalar negative widths and ignored width for
diagonal lines, which breaks PicoMite graphics programs such as clock faces
that use `LINE ..., -2, colour`.

What it changes:

- Allows scalar and array `LINE` widths from `-100` to `100`.
- Treats `0` as a no-op.
- Renders negative widths as centered parallel 1-pixel lines, including
  diagonal lines.

Upstream suitability: good candidate. This is documented PicoMite syntax and
keeps existing positive-width behavior unchanged.

### `0016-add-picomite-array-set-command.patch`

Purpose: support PicoMite/WebMite `ARRAY SET value,array()`.

Why it is needed: PicoMite programs use `ARRAY SET` to initialise numeric and
string arrays. MMB4L had no `ARRAY` command entry, so those programs failed with
`Unknown command` before reaching any array handling.

What it changes:

- Registers the `Array` command.
- Adds `ARRAY SET` for whole integer, floating-point, and string arrays.
- Fills every declared element across all dimensions while preserving MMBasic
  string-length checks.

Upstream suitability: good candidate. This adds documented PicoMite language
syntax without changing existing MMB4L command behaviour.

### `0017-picocalc-print-at-graphics-cursor.patch`

Purpose: make `PRINT @(x,y)` draw positioned text on the PicoCalc framebuffer.

Why it is needed: PicoMite programs often mix `BOX`, `RBOX`, `TEXT`, and
`PRINT @` for screen layouts. The graphics commands already draw to the
PicoCalc DirectFB surface, but MMB4L's `AT()` function only emitted VT100
cursor escapes, so positioned `PRINT` text went to the SSH/ADB terminal instead
of the PicoCalc screen.

What it changes:

- Arms a PicoCalc graphics text cursor from `PRINT @(x,y)` when the default
  display probe identifies the Luckfox PicoCalc framebuffer.
- Mirrors subsequent console characters into the active graphics surface using
  the current graphics font and colours until a line break ends the positioned
  print.
- Keeps the old VT100 terminal cursor behavior for non-PicoCalc targets.

Upstream suitability: target-specific as implemented. A general upstream
version would need a broader policy for when terminal `PRINT @` output should
also target an active graphics surface.

### `0018-keep-immediate-cls-on-console.patch`

Purpose: keep bare `CLS` at the interactive MMBasic prompt from unexpectedly
opening and clearing the PicoCalc graphics surface.

Why it is needed: `0009` intentionally auto-creates the PicoCalc display for
graphics commands so PicoMite programs can draw without explicit desktop-style
setup. But when a user types plain `CLS` at the REPL before graphics is active,
opening a blank `PicoCalc` window or blanking the framebuffer makes it look like
the prompt has disappeared. The prompt is still in the launching terminal, but
the behavior is confusing.

What it changes:

- Bare immediate-mode `CLS` clears the console when no graphics surface exists.
- Program `CLS` still auto-creates and clears the PicoCalc display.
- Explicit graphics use from the REPL remains available through drawing
  commands or coloured `CLS`.

Upstream suitability: target-specific. This preserves MMB4L's terminal prompt
expectations while keeping PicoCalc program compatibility.

## Patch Rules

- Keep upstream `mmb4l/` as a clean submodule checkout whenever possible.
- Store patches here using numbered filenames, for example:
  - `0001-add-picocalc-build-option.patch`
  - `0002-add-framebuffer-backend.patch`
- Each patch should explain why it exists in its commit message.
- Prefer small patches that can be submitted upstream or dropped cleanly.
- Do not silently edit `mmb4l/` without updating this patch queue.

## Apply Patches Manually

From the project root:

```powershell
git -C .\mmb4l apply ..\patches\mmb4l\0001-example.patch
```

Normal users should not need to apply patches manually. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-mmbasic.ps1
```

The wrapper handles patch application automatically.
