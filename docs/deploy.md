# Deploy To PicoCalc

This page documents the repeatable install flow for a PicoCalc running the
Luckfox Lyra Linux image.

## Install Layout

The deploy script installs:

- `mmbasic` to `/usr/local/bin/mmbasic`
- the test runner to `/usr/local/bin/mmb4l-run-tests`
- PATH-visible links under `/usr/bin`
- upstream examples to `/usr/local/share/mmb4l/examples`
- upstream tests to `/usr/local/share/mmb4l/tests`
- PicoCalc target tests to `/usr/local/share/mmb4l/tests/picocalc`
- upstream `sptools` to `/usr/local/share/mmb4l/sptools`

The `tests` and `sptools` directories are installed as siblings because the
upstream test programs include files through paths such as
`../sptools/src/sptest/unittest.inc`.

If `build/mmb4l-luckfox-source` exists, deployment uses that patched source
copy for examples, tests, and `sptools`. That keeps target tests aligned with
the exact patch queue used for the binary. If no patched build source exists,
deployment falls back to the pristine `mmb4l` submodule.

## Deploy

Build first:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-mmbasic.ps1
```

Connect the PicoCalc over ADB, then deploy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-mmbasic.ps1
```

The script stages files under `/tmp/mmb4l-deploy`, copies them into the install
layout, marks executables, prints `mmbasic --version`, and runs a smoke test
through the installed test runner.

To install somewhere else:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-mmbasic.ps1 `
  -InstallBinDir /opt/mmb4l/bin `
  -PathBinDir /usr/bin `
  -InstallShareDir /opt/mmb4l/share
```

The upstream `sptools` scripts use `/usr/local/bin/mmbasic` in shebangs, so the
default keeps the real binary under `/usr/local/bin`. The Luckfox image used for
this project has `/usr/bin` in `PATH`, so the deploy script also creates
`/usr/bin/mmbasic` and `/usr/bin/mmb4l-run-tests` links by default.

## No-Build Release Bundle

For users who only want to install the current tested build, use:

```text
dist/mmbasic-luckfox-lyra-release.tar.gz
```

Copy the archive to the PicoCalc, then run:

```sh
tar xzf mmbasic-luckfox-lyra-release.tar.gz
cd mmbasic-luckfox-lyra-release
sh install-picocalc.sh
mmb4l-run-tests
```

The bundle installs the same target layout as `scripts/deploy-mmbasic.ps1`:

- `mmbasic` to `/usr/local/bin/mmbasic`
- `mmb4l-run-tests` to `/usr/local/bin/mmb4l-run-tests`
- PATH-visible links under `/usr/bin`
- examples, tests, PicoCalc tests, and `sptools` under
  `/usr/local/share/mmb4l`
- `directfbrc` to `/etc/directfbrc`

By default, `install-picocalc.sh` also applies the current device-permission
workaround:

```sh
chmod 666 /dev/fb0 /dev/tty0
```

Set `MMB4L_APPLY_DEVICE_PERMS=0` to skip that step. Set `MMB4L_RUN_SMOKE=0` to
skip the installer's smoke test.

To refresh the release bundle from the current build output:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package-release.ps1 -UseBuildBinary
```

The packager uses the tracked `dist/mmbasic-luckfox-lyra-armv7l` binary by
default. Pass `-UseBuildBinary` after a successful local build to refresh that
tracked binary from `build/mmb4l-luckfox-release/mmbasic`. It uses
`build/mmb4l-luckfox-source` for examples, tests, and `sptools` when available,
matching the deploy script.

## DirectFB Target Setup

The PicoCalc graphics path uses SDL2 over DirectFB. The target must have the
project DirectFB configuration installed at `/etc/directfbrc`; otherwise
DirectFB can try to take over a virtual terminal and graphics can be less
stable when launched from SSH/ADB or a nonstandard console.

`scripts/deploy-mmbasic.ps1` installs `scripts/target/directfbrc` to
`/etc/directfbrc` by default. If applying it manually, the file contents should
be:

```text
quiet
no-cursor
no-banner
no-debug
system=fbdev
fbdev=/dev/fb0
wm=default
mode=320x320
depth=16
pixelformat=RGB16
no-vt
no-vt-switch
no-linux-input-grab
disable-module=keyboard
disable-module=linux_input
```

`quiet` suppresses the DirectFB startup, framebuffer, gamma-ramp, and Fusion
diagnostics that otherwise remain on the physical console after a graphics
program exits. `no-banner` removes the large DirectFB startup banner, and
`no-debug` is harmless on this target but does not replace `quiet`.

The two `disable-module` lines keep DirectFB from opening the PicoCalc keyboard
through its own input drivers; MMBasic receives physical-console input through
stdin instead. This avoids the bad key behavior seen when Linux console input
and DirectFB input both consume the PicoCalc keyboard.

Manual apply command:

```powershell
adb push .\scripts\target\directfbrc /tmp/directfbrc
adb shell 'cp /tmp/directfbrc /etc/directfbrc'
```

On the tested image, non-root display access was also stabilized by allowing
the user process to read and write both `/dev/fb0` and `/dev/tty0`.
The observed default ownership was:

```text
crw-rw----    1 root     tty         4,   0 Dec 31  1969 tty0
crw-rw----    1 root     video      29,   0 Jun 23 10:46 fb0
```

The proven local workaround is:

```powershell
adb shell 'chmod 666 /dev/fb0 /dev/tty0'
```

This is intentionally documented as a device workaround, not a final security
policy. It grants display/console access to every local process and may be
reset when `/dev` is recreated at boot. A later image-level fix should prefer a
proper user/group membership, `mdev`, or equivalent device-permission rule once
the final Luckfox runtime policy is known.

## Run Tests On PicoCalc

Fast install check:

```sh
mmb4l-run-tests --smoke
```

Run the full target health suite:

```sh
mmb4l-run-tests
```

Verify that text-mode `CLS` clears the physical console instead of blanking the
DirectFB graphics surface:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-picocalc-text-cls.ps1
```

With no arguments, the runner discovers and runs every installed `tst*.bas`
under `/usr/local/share/mmb4l/tests`, including the upstream test files and the
project PicoCalc tests under `tests/picocalc`. It also runs target health
checks for:

- required `/etc/directfbrc` options
- read/write access to `/dev/fb0`
- read/write access to `/dev/tty0`
- installed PicoCalc target tests

The runner exports `MMB4L_TEST_TARGET=picocalc-luckfox-lyra` so display-size
tests assert the real 320x320 PicoCalc framebuffer instead of upstream desktop
MMB4L simulation sizes.

Each BASIC test file is also wrapped with a timeout so a hardware or networking
operation cannot hang the entire health report. The default is 60 seconds per
file:

```sh
MMB4L_TEST_TIMEOUT=120 mmb4l-run-tests
MMB4L_TEST_TIMEOUT=0 mmb4l-run-tests
```

Cursor-position checks and DirectFB-backed simulation checks are disabled by
default because they can corrupt the shell prompt or fail for non-root console
users. The runner prints skip reasons for those intentionally disabled checks.
To opt into them explicitly:

```sh
MMB4L_TEST_CURSOR=1 mmb4l-run-tests tst_mminfo.bas
MMB4L_TEST_DIRECTFB=1 mmb4l-run-tests tst_mminfo.bas
```

The runner continues through the requested test files, prints `PASS:` or
`FAIL:` for each file, then exits nonzero if MMBasic exits nonzero or if any
test output contains a `FAIL (` summary. This is needed because upstream BASIC
assertion failures can still leave the interpreter process with exit status 0.
At the end it lists failed files individually, lists skipped `NO ASSERTIONS`
checks individually, and reports success, failed, skipped, and total counts with
percentages.
Known `NO ASSERTIONS` entries in the default suite are platform-gated upstream
tests: PicoMite-only drive and string escape checks, MMB4L font-address checks,
cursor checks that require an interactive console, and display simulation checks
that require a wider simulated display than the 320x320 PicoCalc framebuffer.

The Luckfox image used here is a Buildroot/BusyBox environment, not a full GNU
desktop distribution. When a test only needs a simple tool behavior, this
project patches the test or runtime expectation instead of requiring full GNU
coreutils. If a future MMB4L feature genuinely needs a GNU-only behavior, add
that as an explicit SDK/runtime dependency and document it here.

Run the smaller legacy core subset:

```sh
mmb4l-run-tests --core
```

This runs only the curated top-level upstream files that were used before the
full health suite became the default.

Run the exact upstream test entry point:

```sh
mmb4l-run-tests --upstream-entrypoint
```

This uses upstream `tests/run_tests.bas` discovery directly. The older
`--upstream-all` flag is kept as a deprecated alias for the default full health
suite because it did not include the project PicoCalc tests.

Run individual upstream tests:

```sh
mmb4l-run-tests tst_math.bas tst_strings.bas
```

Pass arguments to the upstream test framework after `--`:

```sh
mmb4l-run-tests --upstream-entrypoint -- --verbose
```

Some upstream tests exercise graphics, audio, gamepad, keyboard, or manual
flows. Those may require the PicoCalc display, input devices, ALSA setup, or
interactive use rather than a plain ADB shell.
