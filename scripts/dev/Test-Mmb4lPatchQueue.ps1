param(
  [switch]$SkipBuild,
  [switch]$SkipWhitespace
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Get-DevRepoRoot
Assert-DevGitIndexUnlocked $repoRoot

if (-not $SkipWhitespace) {
  Invoke-DevCommand -FilePath 'git' -ArgumentList @(
    'diff', '--check', '--', '.', ':(exclude)patches/mmb4l/*.patch'
  ) -WorkingDirectory $repoRoot
  Invoke-DevCommand -FilePath 'git' -ArgumentList @(
    'diff', '--cached', '--check', '--', '.', ':(exclude)patches/mmb4l/*.patch'
  ) -WorkingDirectory $repoRoot
}

if (-not $SkipBuild) {
  Invoke-DevCommand -FilePath 'powershell' -ArgumentList @(
    '-ExecutionPolicy', 'Bypass', '-File', '.\scripts\build-mmbasic.ps1'
  ) -WorkingDirectory $repoRoot
}

Write-Output 'Patch queue validation completed.'
