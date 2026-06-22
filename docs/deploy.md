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
PicoCalc environment. From an ADB shell, console cursor and terminal-size
assertions are skipped with a notice because ADB is not the PicoCalc console.
Run the same command from the PicoCalc console for fuller console/framebuffer
coverage.

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
