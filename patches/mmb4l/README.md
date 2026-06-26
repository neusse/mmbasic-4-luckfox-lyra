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

Purpose: keep bare text-mode `CLS` from unexpectedly opening and clearing the
PicoCalc graphics surface.

Why it is needed: `0009` intentionally auto-creates the PicoCalc display for
graphics commands so PicoMite programs can draw without explicit desktop-style
setup. But when a program or REPL session uses plain `CLS` before graphics is
active, opening a blank `PicoCalc` window or blanking the framebuffer hides
subsequent terminal text. Text-mode programs expect `CLS` to clear the terminal
and resume output at the top of the console.

What it changes:

- Bare `CLS` clears the console when no graphics surface exists.
- Bare `CLS` still clears graphics after a graphics surface exists.
- Coloured `CLS` and drawing commands still auto-create the PicoCalc display
  when needed.

Upstream suitability: target-specific. This preserves MMB4L's terminal prompt
expectations while keeping PicoCalc program compatibility.

### `0019-luckfox-https-rest-client.patch`

Purpose: add Luckfox/Linux networking compatibility for REST and read-only
WiFi status without making MMBasic own Linux network configuration.

Why it is needed: WebMite programs expect network commands, but on Luckfox the
Linux OS owns WiFi association, DHCP, routing, TLS certificates, and system
time. BASIC programs still need a practical way to inspect WiFi state, scan,
and make outbound HTTPS API calls.

What it changes:

- Links ARM builds against the Luckfox SDK `libcurl`.
- Adds `WEB REST GET`, `WEB REST POST`, `WEB REST HEADER`, and
  `WEB REST CLEAR HEADERS` backed by libcurl/OpenSSL.
- Writes REST response bodies into longstring-compatible integer arrays and
  optionally returns HTTP status codes.
- Adds `WEB SCAN array%()` for captured SSID scan results.
- Adds `WEB NTP [offset [, server$]]` as a compatibility no-op because Linux
  owns the system clock.
- Adds read-only `OPTION WIFI ssid$, password$`; it succeeds when Linux is
  already connected to `ssid$` and otherwise points users at Linux networking
  tools.
- Makes Telnet, TFTP, UDP, and MQTT WEB command families fail explicitly
  instead of pretending to be implemented.

Upstream suitability: low as-is. The policy and libcurl backend are correct for
Luckfox Linux, but upstream MMB4L would need a broader cross-Linux networking
design before taking this surface.

### `0020-picocalc-mode-compatibility-noop.patch`

Purpose: let portable PicoMite/CMM2 graphics programs that begin with `MODE`
run on the fixed Luckfox PicoCalc framebuffer.

Why it is needed: the PicoCalc display has no switchable MMBasic video modes,
but rejecting `MODE 1` stops otherwise-compatible programs before their drawing
commands can use the 320x320 graphics surface.

What it changes:

- Accepts valid `MODE` syntax when the real PicoCalc framebuffer is detected.
- Ensures the default 320x320 graphics surface exists.
- Leaves simulated CMM2/MMB4W/PicoMiteVGA mode handling unchanged.
- Keeps invalid/malformed `MODE` commands as errors.

Upstream suitability: target-specific. A general upstream version would need a
broader embedded-Linux display policy.

### `0021-picocalc-mm-font-metric-aliases.patch`

Purpose: support `MM.FONTWIDTH` and `MM.FONTHEIGHT` as direct PicoMite-style
font metric aliases.

Why it is needed: MMB4L already exposes these metrics through
`MM.INFO(FONTWIDTH)` and `MM.INFO(FONTHEIGHT)`, but some PicoMite-era programs
use the shorter `MM.FONTWIDTH` and `MM.FONTHEIGHT` forms when translating text
columns and rows into pixels. Without tokens for those aliases, programs that
do not use `Option Explicit` silently create ordinary variables with value
zero, causing all positioned text to collapse to the same screen coordinate.

What it changes:

- Adds `MM.FontWidth` and `MM.FontHeight` no-argument function aliases.
- Backs both aliases with the same graphics font metrics used by `MM.INFO`.
- Adds a PicoCalc target regression test for the aliases.

Upstream suitability: reasonable. The aliases are compatibility surface over
existing font metrics, though upstream may prefer to confirm the exact dialects
that publish these names.

### `0022-picocalc-print-at-cursor-lifetime.patch`

Purpose: keep the PicoCalc `PRINT @(x,y)` graphics cursor scoped to the current
`PRINT` command.

Why it is needed: `PRINT @(x,y) "text";` suppresses the newline, so the
previous framebuffer cursor stayed armed and later unpositioned `PRINT`
commands could continue drawing at the old graphics location. Slot-machine,
menu, and calculator-style programs often mix positioned and normal output, so
this produced smeared or duplicated screen text.

What it changes:

- Clears any old PicoCalc graphics print cursor at the start of each `PRINT`.
- Lets the current `PRINT @(x,y)` re-arm the cursor normally when `@(...)` is
  evaluated.
- Adds a PicoCalc target regression test to ensure an unpositioned later
  `PRINT` does not draw into the old framebuffer location.

Upstream suitability: target-specific as long as the PicoCalc framebuffer
mirroring remains target-specific. The lifetime rule is still broadly sensible
for any future graphics-backed `PRINT @` implementation.

### `0023-picocalc-beep-noop.patch`

Purpose: accept old BASIC `BEEP` statements without requiring a working
Luckfox/PicoCalc audio backend.

Why it is needed: many text games and menu programs use `BEEP` for simple
feedback. Rejecting the command stops the program even though the missing sound
does not usually affect program logic.

What it changes:

- Adds `BEEP` as a visible MMBasic command.
- Implements it as a compatibility no-op; it accepts the statement and
  generates no audio.
- Keeps `BEEP` visible in `LIST COMMANDS` so `mmb4l-check-basic` can identify
  it and warn that audio is not currently supported.
- Adds a PicoCalc target regression test for bare `BEEP` and argument-bearing
  `BEEP`.

Upstream suitability: target-specific as a policy choice. A fuller upstream
implementation would likely route `BEEP` through the existing audio subsystem,
but the no-op is useful for PicoCalc compatibility until audio hardware support
is defined.

### `0024-picocalc-drive-noop.patch`

Purpose: accept old PicoMite-style `DRIVE "A:"` / `DRIVE "B:"` statements
without changing Linux path behavior.

Why it is needed: some SD card program menus select a DOS-style drive before
running `CHDIR`. Linux has no A:/B: drive concept, and MMB4L already handles
drive prefixes in path arguments, so rejecting `DRIVE` stops otherwise usable
programs.

What it changes:

- Adds `DRIVE` as a visible MMBasic command.
- Implements it as a compatibility no-op; Linux paths and `CHDIR` remain
  authoritative.
- Keeps `DRIVE` visible in `LIST COMMANDS` so `mmb4l-check-basic` can warn
  users that no drive switch occurs.
- Adds a PicoCalc target regression test that verifies `DRIVE` does not change
  `CWD$`.

Upstream suitability: target-specific as a compatibility policy. A fuller
portability layer could map drive names to configured directories, but that is
intentionally deferred because silent mount remapping can surprise relative
path behavior.

### `0025-picocalc-page-write-copy.patch`

Purpose: enable `PAGE WRITE 1` and `PAGE COPY 1 TO 0` on the PicoCalc
framebuffer.

Why it is needed: some PicoMite/CMM2 graphics programs render into page 1 and
copy that page to page 0 for presentation. MMB4L already has generic graphics
surfaces and PAGE dispatch, but `PAGE` was rejected on non-CMM2/MMB4W targets
before it reached the existing implementation.

What it changes:

- Allows `PAGE` on the detected PicoCalc framebuffer.
- Ensures display page 0 exists before dispatch.
- Creates page 1 as a same-size off-screen graphics buffer on first `PAGE` use.
- Adds a PicoCalc target regression test for `PAGE WRITE 1` plus
  `PAGE COPY 1 TO 0`.

Upstream suitability: useful as a target-specific compatibility bridge. A more
general upstream version may want configurable page creation policy, but this
keeps PicoCalc behavior narrow and predictable.

### `0026-picocalc-pixel-fill.patch`

Purpose: support PicoMite/WebMite `PIXEL FILL x, y, colour` flood fill.

Why it is needed: some graphics programs use `PIXEL FILL` to paint a connected
region bounded by existing pixels. MMB4L only implemented `PIXEL x, y[, colour]`
and array pixel plotting, so the `FILL` subcommand fell through to expression
parsing and failed at runtime.

What it changes:

- Adds `PIXEL FILL x, y, colour` parsing under the existing `PIXEL` command.
- Flood-fills the active graphics surface using four-neighbour connectivity.
- Works with the PicoCalc default display and off-screen pages selected by
  `PAGE WRITE`.
- Adds a PicoCalc target regression test for bounded flood fill.

Upstream suitability: reasonable as a compatibility feature. It is documented
PicoMite/WebMite graphics syntax and is implemented against the existing generic
MMB4L graphics surface.

### `0027-picocalc-separate-sprite-page-ids.patch`

Purpose: keep PicoCalc `SPRITE` IDs from colliding with `PAGE` surfaces.

Why it is needed: PicoMite-style programs can use `PAGE WRITE 1` and
`SPRITE READ 1` in the same program. The default MMB4L sprite mapping uses
surface 1 for sprite 1, which collides with the PicoCalc off-screen page 1
created by the PAGE compatibility patch.

What it changes:

- Uses the existing CMM2/PicoMite internal sprite ID offset when the PicoCalc
  framebuffer is detected.
- Keeps desktop/default MMB4L sprite IDs unchanged when not on PicoCalc.
- Adds a PicoCalc target regression test proving `PAGE 1` and `SPRITE 1` can
  coexist.

Upstream suitability: target-specific as written. The general issue is a real
dialect-compatibility concern, but the switch is tied to PicoCalc framebuffer
detection.

### `0028-picocalc-audio-open-fallback.patch`

Purpose: let BASIC programs using `PLAY SOUND` continue when the PicoCalc has
no usable SDL/ALSA audio device.

Why it is needed: graphics and game programs often use `PLAY SOUND` for simple
feedback. On the Luckfox PicoCalc target, SDL audio can fail to open with a
hardware-parameter or permission error. Treating that as a fatal MMBasic error
stops otherwise usable programs.

What it changes:

- Adds an audio-open helper that attempts the normal SDL audio path first.
- If SDL audio cannot open, disables audio for the current process and returns
  success.
- Leaves systems with working audio on the normal SDL backend.
- Adds a PicoCalc target regression test for `PLAY SOUND` plus `PLAY STOP`.

Upstream suitability: compatibility-oriented. A more complete solution may add
target audio configuration, but silent fallback is useful for no-audio embedded
targets and keeps old BASIC programs running.

### `0029-picocalc-continuation-lines.patch`

Purpose: support PicoMite/WebMite-style source continuation lines using a
space followed by `_` at the end of a physical line.

Why it is needed: PicoMite V6 documentation describes continuation lines for
splitting long BASIC statements. Without this support MMB4L treats `_` as a
variable name, so `Option Explicit` reports `_ is not declared`; without
`Option Explicit`, the next physical line can be parsed as a separate command
and fail on a leading parenthesis.

What it changes:

- Joins continued physical source lines during program file loading before
  tokenisation.
- Removes the continuation marker (` _`) without inserting extra characters,
  matching the documented concatenation model.
- Keeps source error annotations pointed at the first physical line of the
  continued statement.
- Adds a PicoCalc regression test for continued arithmetic and boolean
  expressions.

Upstream suitability: reasonable as a PicoMite/WebMite language-compatibility
feature. A fuller upstream implementation may add `OPTION CONTINUATION LINES`
state; this patch enables the documented file-loading behavior for compatibility
with existing programs.

### `0030-picocalc-graphics-backend-identity.patch`

Purpose: expose the active graphics backend so target tests can prove which
display path the Luckfox PicoCalc build is exercising.

Why it is needed: the planned native fbdev backend must not be hidden behind
silent SDL2/DirectFB fallback. BASIC and the target runner need an observable
backend identity before the display path is changed.

What it changes:

- Adds a graphics backend enum.
- Adds `graphics_backend_current()` and `graphics_backend_name()`.
- Adds `MM.INFO$(GRAPHICS BACKEND)`.
- Adds a PicoCalc target regression test that expects `FBDEV`.

Current limitations:

- This patch still reports `SDL` on the current PicoCalc build. The later
  fbdev patches will switch the PicoCalc release path to `FBDEV`.

Upstream suitability: target-supporting. The backend identity query is broadly
useful, but the immediate motivation is proving Luckfox/PicoCalc backend
selection during the fbdev conversion.

### `0031-picocalc-fbdev-presenter.patch`

Purpose: add the native Linux fbdev presenter that will replace the
SDL2/DirectFB PicoCalc release display path.

Why it is needed: the VM-style framebuffer plan requires MMBasic to draw into
a software surface first, then present that surface directly to `/dev/fb0`.
This patch adds the low-level presenter before wiring it into the graphics
surface lifecycle.

What it changes:

- Adds `picocalc_fbdev.h` and `picocalc_fbdev.c`.
- Opens and verifies a 320x320 RGB565 Linux framebuffer.
- Maps `/dev/fb0` and converts ARGB/RGB888 source pixels to RGB565 rows.
- Adds a PPM screenshot helper for target-side framebuffer diagnostics.
- Adds a PicoCalc fbdev pixel smoke test and a PowerShell target verification
  script.

Current limitations:

- The presenter is compiled but not selected as the active PicoCalc graphics
  backend yet. The next patch creates the PicoCalc default display as a
  software surface and flushes it through this presenter.

Upstream suitability: target-specific as written. The fbdev presenter model may
be useful to upstream MMB4L, but this implementation intentionally validates the
PicoCalc 320x320 RGB565 framebuffer.

### `0032-picocalc-software-display-surface.patch`

Purpose: make the PicoCalc default display a VM-style software framebuffer
presented through native Linux fbdev.

Why it is needed: drawing commands should mutate an in-memory MMB4L surface
first, then flush that surface to `/dev/fb0`. This avoids SDL/DirectFB window
creation on the PicoCalc release graphics path and makes the active backend
observable as `FBDEV`.

What it changes:

- Opens `/dev/fb0` through the native fbdev presenter when PicoCalc graphics
  are first needed.
- Creates the PicoCalc default display as `GRAPHICS_SURFACE_N`, a 320x320
  software buffer.
- Adds visible-surface generation counters and a `graphics_present_if_needed()`
  flush hook.
- Marks pixel-mutating graphics paths through `graphics_mark_surface_dirty()`.
- Flushes the visible software surface during background refresh and once more
  before graphics shutdown.

Current limitations:

- `FRAMEBUFFER` command semantics still need the follow-up patch so page names
  map cleanly onto the software display/frame/layer surfaces.
- Physical-console input and REPL screen rendering still use the existing
  policy until the console and evdev patches land.

Upstream suitability: target-specific as written. The software-surface plus
fbdev-presenter split is a good embedded-Linux model, but this patch is tied to
the Luckfox PicoCalc framebuffer probe and 320x320 display.

### `0033-picocalc-framebuffer-command-surface.patch`

Purpose: route PicoCalc `FRAMEBUFFER` commands through the VM-style software
display surfaces.

Why it is needed: after the PicoCalc default display moved from SDL surface `0`
to software surface `N`, the existing compatibility layer still treated
`FRAMEBUFFER N` as surface `0`. `FRAMEBUFFER CREATE` and `WRITE F` therefore
failed before a frame surface could be used.

What it changes:

- Maps `FRAMEBUFFER N` to `GRAPHICS_SURFACE_N`.
- Keeps `FRAMEBUFFER F` and `FRAMEBUFFER L` on the existing frame/layer
  software surfaces.
- Keeps `FRAMEBUFFER CREATE`, `WRITE`, `COPY`, and `MERGE` operating on
  software pixels.
- Adds `FRAMEBUFFER SYNC` and makes `FRAMEBUFFER WAIT` flush pending fbdev
  presentation through `graphics_present_if_needed()`.
- Adds a PicoCalc target regression test for `CREATE`, `WRITE F`, `COPY F,N`,
  `WAIT`, and visible pixel readback.

Current limitations:

- The optional `FRAMEBUFFER COPY ..., B` background flag remains accepted but
  not semantically implemented by MMB4L.

Upstream suitability: target-specific as written. The `N/F/L` mapping is useful
for PicoMite compatibility, but the fbdev presentation hook is Luckfox/PicoCalc
specific.

### `0034-picocalc-console-policy.patch`

Purpose: make PicoCalc REPL/display ownership explicit instead of inheriting
DirectFB or SDL side effects.

Why it is needed: MMBasic can be run from SSH/ADB terminals, Linux pseudo
terminals, or the physical PicoCalc console. Graphics should not steal a normal
terminal REPL, but the physical console needs a framebuffer-backed text path
when MMBasic owns the screen.

What it changes:

- Adds a PicoCalc console policy module with `TERMINAL` and `SCREEN` modes.
- Defaults SSH/ADB and `/dev/pts/*` sessions to terminal mode.
- Detects Linux virtual consoles such as `/dev/tty0` and `/dev/tty1` as screen
  mode, with `MMB4L_PICOCALC_CONSOLE=screen|terminal` as an override.
- Adds `MM.INFO$(CONSOLE MODE)` so users and tests can inspect the selected
  policy.
- Keeps positioned `PRINT @(x,y)` graphics output working while routing normal
  console text to the framebuffer only in screen mode.
- Makes `CLS CONSOLE` and bare text-mode `CLS` clear the framebuffer console
  when MMBasic is running on the physical PicoCalc console.

Current limitations:

- Screen-mode input still uses the existing terminal input path until the evdev
  keyboard patch lands.

Upstream suitability: partly reusable. The terminal/screen policy and
diagnostic are useful embedded-Linux structure, but the virtual-console default
and framebuffer renderer are PicoCalc-targeted.

### `0035-picocalc-evdev-input.patch`

Purpose: read the PicoCalc keyboard through Linux evdev when MMBasic owns the
physical screen.

Why it is needed: on the Luckfox PicoCalc the keyboard is exposed as a Linux
input device (`Picocalc Keyboard`) at `/dev/input/event0`, with the stable path
`/dev/input/by-path/platform-ff040000.i2c-event-kbd`. Reading raw tty bytes
from the physical console can produce garbled or missing keys once framebuffer
graphics are active.

What it changes:

- Adds a nonblocking PicoCalc evdev backend that pumps `struct input_event`
  records into MMB4L's existing console RX buffer.
- Uses the VM-style model where a platform keyboard backend decodes hardware
  events, then feeds ordinary MMBasic key codes into shared console input.
- In `SCREEN` console mode, `console_pump_input()` reads evdev and does not
  read duplicate Linux tty bytes.
- Keeps SSH/ADB and GUI terminal sessions on the existing stdin path.
- Maps common printable keys, arrows, navigation keys, F1-F12, delete,
  backspace, enter, escape, shift/control/alt/gui modifiers, and lock state.
- Adds `MMB4L_PICOCALC_EVDEV=/path/to/event` as an override and `off|none|0`
  as a disable switch.

Current limitations:

- The keymap is a practical PicoCalc/Linux evdev map, not a full international
  keyboard layout engine.
- Runtime permission for `/dev/input/event0` still depends on the Linux image's
  device node permissions or user groups.

Upstream suitability: mostly target-specific. The backend shape is generally
useful for embedded Linux, but the default device path and keymap target the
Luckfox PicoCalc.

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
