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

Run the PicoCalc core test set:

```sh
mmb4l-run-tests
```

The core set runs the top-level upstream tests patched for the Luckfox Lyra
PicoCalc environment. Cursor-position checks and DirectFB-backed simulation
checks are disabled by default because they can corrupt the shell prompt or
fail for non-root console users. To opt into them explicitly:

```sh
MMB4L_TEST_CURSOR=1 mmb4l-run-tests tst_mminfo.bas
MMB4L_TEST_DIRECTFB=1 mmb4l-run-tests tst_mminfo.bas
```

The runner exits nonzero if MMBasic exits nonzero or if a test output contains
a `FAIL (` summary. This is needed because upstream BASIC assertion failures
can still leave the interpreter process with exit status 0.

The Luckfox image used here is a Buildroot/BusyBox environment, not a full GNU
desktop distribution. When a test only needs a simple tool behavior, this
project patches the test or runtime expectation instead of requiring full GNU
coreutils. If a future MMB4L feature genuinely needs a GNU-only behavior, add
that as an explicit SDK/runtime dependency and document it here.

Run the exact upstream test entry point:

```sh
mmb4l-run-tests --upstream-all
```

This is broader and slower than the PicoCalc core set because it uses upstream
`tests/run_tests.bas` discovery. The runner streams output live so it does not
look frozen during long runs.

Run individual upstream tests:

```sh
mmb4l-run-tests tst_math.bas tst_strings.bas
```

Pass arguments to the upstream test framework after `--`:

```sh
mmb4l-run-tests --upstream-all -- --verbose
```

Some upstream tests exercise graphics, audio, gamepad, keyboard, or manual
flows. Those may require the PicoCalc display, input devices, ALSA setup, or
interactive use rather than a plain ADB shell.
