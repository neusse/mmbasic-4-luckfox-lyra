# AGENTS.md

Repository rules for Codex and other automated agents working in this project.

## Project Goal

This repository is a repeatable MMB4L-based build, patch, test, packaging, and
documentation workspace for the Luckfox Lyra PicoCalc. Prefer stable scripts
and documented workflows over one-off manual command sequences.

## Windows PowerShell Rules

- Prefer direct PowerShell commands when the shell is already PowerShell.
- If `pwsh.exe -Command` or `powershell -Command` is required, wrap the whole
  script in single quotes.
- Do not use Bash-style `\"` escaping in PowerShell commands.
- For regex patterns containing `|`, use single quotes.
- Prefer `powershell -ExecutionPolicy Bypass -File .\scripts\...\script.ps1`
  for repository scripts.

## Fixed Automation Entry Points

Use the scripts documented in `docs/dev-automation.md` for repeated workflows:

- Patch snapshot: `scripts/dev/New-Mmb4lPatchSnapshot.ps1`
- Patch generation: `scripts/dev/New-Mmb4lPatchFromSnapshot.ps1`
- Patch queue validation: `scripts/dev/Test-Mmb4lPatchQueue.ps1`
- Build/deploy/test: `scripts/dev/Invoke-Mmb4lBuildDeployTest.ps1`
- Release packaging: `scripts/dev/New-Mmb4lReleasePackage.ps1`
- Pre-commit gate: `scripts/dev/Test-Mmb4lPreCommit.ps1`
- Physical text visual test: `scripts/dev/Invoke-PicoCalcVisualTextTest.ps1`
- Automation self-test: `scripts/dev/Test-DevAutomation.ps1`

Do not retype long `adb`, WSL, build, deploy, release, or patch-generation
flows unless actively debugging a script failure.

## Patch Queue Rules

- Do not edit the `mmb4l/` submodule as the final source of truth.
- Make target changes in `build/mmb4l-luckfox-source`, then convert them into
  numbered patches under `patches/mmb4l/`.
- Create a snapshot before patch edits with `New-Mmb4lPatchSnapshot.ps1`.
- Generate patches with `New-Mmb4lPatchFromSnapshot.ps1`.
- Validate patches by applying/building them. Do not blindly rewrite patch
  whitespace because valid patch hunk lines can look like trailing whitespace
  to generic source checks.
- Document each new patch in `patches/mmb4l/README.md`.

## Verification Rules

Before claiming work is complete, run fresh verification and read the output:

- For script changes, run `scripts/dev/Test-DevAutomation.ps1`.
- For patch changes, run `scripts/dev/Test-Mmb4lPatchQueue.ps1`.
- For target behavior changes, run `scripts/dev/Invoke-Mmb4lBuildDeployTest.ps1`
  or a focused equivalent with logs.
- For release artifact changes, run `scripts/dev/New-Mmb4lReleasePackage.ps1`
  or `-VerifyOnly` as appropriate.
- For physical display behavior, run `scripts/dev/Invoke-PicoCalcVisualTextTest.ps1`
  and ask the user to confirm the screen. Do not treat exit code alone as
  physical-screen verification.

## Git Safety

- Do not run parallel git commands.
- Do not commit or push while `.git/index.lock` exists.
- If `.git/index.lock` exists, check for active git processes before removing
  it.
- Use `git status --short --branch` before staging and before committing.
- Stage intentionally. Avoid mixing unrelated work in a commit.
- Never use destructive git commands such as `git reset --hard` or
  `git checkout --` unless the user explicitly asks for that operation.

## Release Artifacts

The tracked release artifacts are under `dist/`, even though `dist/` is ignored
for new files. Use `git add -u dist` for refreshed tracked release files.
Use `New-Mmb4lReleasePackage.ps1` to regenerate and verify the release bundle.

## Target Policy

The supported runtime target is the Luckfox Lyra PicoCalc Linux console/text
environment with native `/dev/fb0` graphics and evdev keyboard input. SSH/ADB
operation is supported for development. GUI/X11 behavior may vary and should
not be treated as the primary correctness target.
