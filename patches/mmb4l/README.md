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
