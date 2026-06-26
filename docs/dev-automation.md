# Development Automation

This project uses fixed scripts for repeated build, patch, deploy, test,
release, and git-safety work. Use these scripts instead of retyping ad hoc
command sequences.

## Patch Creation

Create a snapshot before editing generated MMB4L source:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\New-Mmb4lPatchSnapshot.ps1 -Name screen-console-vt100
```

After editing `build\mmb4l-luckfox-source`, generate and validate the patch:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\New-Mmb4lPatchFromSnapshot.ps1 `
  -SnapshotDir .\tmp\patch-snapshots\<snapshot-dir> `
  -Name screen-console-vt100
```

The patch generator:

- Creates the next numbered `patches\mmb4l\NNNN-name.patch`.
- Normalizes paths to `a/src/...` and `b/src/...`.
- Validates the patch with `git apply --check` against the snapshot.
- Does not rewrite patch whitespace after creation.

## Patch Queue Validation

Lightweight validation:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\Test-Mmb4lPatchQueue.ps1 -SkipBuild
```

Full validation:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\Test-Mmb4lPatchQueue.ps1
```

This script checks normal source whitespace while excluding `.patch` files from
`git diff --check`. Patch files are validated by apply/build behavior, not by
blind whitespace cleanup.

## Build, Deploy, And Test

Run the full target flow:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\Invoke-Mmb4lBuildDeployTest.ps1
```

Run focused screen-console tests plus the full suite:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\Invoke-Mmb4lBuildDeployTest.ps1 `
  -FocusedTests /usr/local/share/mmb4l/tests/picocalc/tst_picocalc_screen_console_cursor.bas,`
                /usr/local/share/mmb4l/tests/picocalc/tst_picocalc_screen_console_vt100.bas `
  -ScreenModeFocused
```

Logs are written under `logs\dev-workflow\`.

## Release Packaging

Build and refresh the no-build release package:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\New-Mmb4lReleasePackage.ps1
```

Verify the current release artifacts without rebuilding:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\New-Mmb4lReleasePackage.ps1 -VerifyOnly
```

The verifier checks the binary, ZIP, TAR.GZ, checksums, installer, runner,
checker, docs, and PicoCalc tests are present.

## Git Safety

Run the pre-commit gate:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\Test-Mmb4lPreCommit.ps1
```

For a faster local check without rebuilding:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\Test-Mmb4lPreCommit.ps1 -SkipBuild
```

The gate refuses to run if `.git\index.lock` exists, shows git status, validates
the patch queue, verifies release artifacts, and prints the staged diff stat.
Do not run parallel git commands.

## Physical Screen Verification

Run the standard visual text test:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\Invoke-PicoCalcVisualTextTest.ps1
```

Ask the screen observer to confirm:

- `CLS` starts text at the top-left.
- VT100 clear does not render raw `[2J` text.
- Repeated `PRINT @` redraws do not scroll the menu text away.

## Automation Self-Test

Before changing these scripts, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\Test-DevAutomation.ps1
```

This parses every script in `scripts\dev` and verifies the patch generator with
a tiny temporary source tree.
