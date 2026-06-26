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
- `mmb4l-check-basic` to `/usr/local/bin/mmb4l-check-basic`
- PATH-visible links under `/usr/bin`
- examples, tests, PicoCalc tests, and `sptools` under
  `/usr/local/share/mmb4l`
- host-side fbdev screenshot verification script under
  `scripts/verify-picocalc-fbdev.ps1`

`install-picocalc.sh` does not change device permissions by default. For a
quick development-only non-root test, run:

```sh
chmod 666 /dev/fb0 /dev/tty0 /dev/input/event0
```

Set `MMB4L_APPLY_DEVICE_PERMS=1` to have the installer apply that workaround.
Set `MMB4L_RUN_SMOKE=0` to skip the installer's smoke test.

To refresh the release bundle from the current build output:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package-release.ps1 -UseBuildBinary
```

The packager uses the tracked `dist/mmbasic-luckfox-lyra-armv7l` binary by
default. Pass `-UseBuildBinary` after a successful local build to refresh that
tracked binary from `build/mmb4l-luckfox-release/mmbasic`. It uses
`build/mmb4l-luckfox-source` for examples, tests, and `sptools` when available,
matching the deploy script.

## Native Framebuffer Target Setup

The current PicoCalc graphics path presents the MMBasic display directly through
Linux fbdev at `/dev/fb0`. Physical-console keyboard input is read through the
PicoCalc evdev keyboard at `/dev/input/event0`, or the stable by-path symlink:

```text
/dev/input/by-path/platform-ff040000.i2c-event-kbd
```

DirectFB is no longer installed or required by the release bundle. The legacy
`scripts/target/directfbrc` file remains in the repository only for testing old
SDL/DirectFB builds explicitly.

Verify fbdev on the target:

```sh
test -e /dev/fb0
fbset -fb /dev/fb0
mmbasic -e 'Print MM.Info$("GRAPHICS BACKEND")'
```

Expected backend output:

```text
FBDEV
```

The tested image exposes the display and input devices with restrictive
permissions:

```text
crw-rw----    1 root     tty         4,   0 Dec 31  1969 tty0
crw-rw----    1 root     video      29,   0 Jun 23 10:46 fb0
crw-rw----    1 root     tty        13,  64 ... event0
```

For non-root runs, the current practical workaround is:

```powershell
adb shell 'chmod 666 /dev/fb0 /dev/tty0 /dev/input/event0'
```

This is intentionally documented as a device workaround, not a final security
policy. It grants display/console/input access to every local process and may
be reset when `/dev` is recreated at boot. A later image-level fix should
prefer a proper user/group membership, `mdev`, or equivalent device-permission
rule once the final Luckfox runtime policy is known.

To install the legacy DirectFB config during an ADB deploy of an old
SDL/DirectFB build, pass an explicit path:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-mmbasic.ps1 `
  -LegacyDirectFbConfigPath /etc/directfbrc
```

That option is not used by the normal release package.

## Run Tests On PicoCalc

Fast install check:

```sh
mmb4l-run-tests --smoke
```

Run the full target health suite:

```sh
mmb4l-run-tests
```

Verify that text-mode `CLS` clears the physical console instead of forcing a
graphics clear:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-picocalc-text-cls.ps1
```

With no arguments, the runner discovers and runs every installed `tst*.bas`
under `/usr/local/share/mmb4l/tests`, including the upstream test files and the
project PicoCalc tests under `tests/picocalc`. It also runs target health
checks for:

- read/write access to `/dev/fb0`
- read/write access to `/dev/tty0`
- read access to `/dev/input/event0`
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

Cursor-position checks and legacy SDL/DirectFB-backed simulation checks are
disabled by default because they can corrupt the shell prompt or fail for
non-root console users. The runner prints skip reasons for those intentionally
disabled checks. To opt into them explicitly:

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
