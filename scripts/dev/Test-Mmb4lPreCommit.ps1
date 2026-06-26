param(
  [switch]$SkipBuild,
  [switch]$SkipReleaseVerify
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Get-DevRepoRoot
Assert-DevGitIndexUnlocked $repoRoot

Invoke-DevCommand -FilePath 'git' -ArgumentList @('status', '--short', '--branch') -WorkingDirectory $repoRoot

$patchQueueArgs = @('-ExecutionPolicy', 'Bypass', '-File', '.\scripts\dev\Test-Mmb4lPatchQueue.ps1')
if ($SkipBuild) { $patchQueueArgs += '-SkipBuild' }
Invoke-DevCommand -FilePath 'powershell' -ArgumentList $patchQueueArgs -WorkingDirectory $repoRoot

if (-not $SkipReleaseVerify) {
  Invoke-DevCommand -FilePath 'powershell' -ArgumentList @(
    '-ExecutionPolicy', 'Bypass', '-File', '.\scripts\dev\New-Mmb4lReleasePackage.ps1', '-VerifyOnly'
  ) -WorkingDirectory $repoRoot
}

Invoke-DevCommand -FilePath 'git' -ArgumentList @('diff', '--cached', '--stat') -WorkingDirectory $repoRoot
Write-Output 'Pre-commit checks completed.'
