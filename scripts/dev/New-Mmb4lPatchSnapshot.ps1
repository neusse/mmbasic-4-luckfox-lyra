param(
  [Parameter(Mandatory = $true)][string]$Name,
  [string]$SourceDir = '',
  [string]$OutputRoot = ''
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Get-DevRepoRoot
Assert-DevGitIndexUnlocked $repoRoot

if (-not $SourceDir) { $SourceDir = Join-Path $repoRoot 'build\mmb4l-luckfox-source' }
if (-not $OutputRoot) { $OutputRoot = Join-Path $repoRoot 'tmp\patch-snapshots' }

$sourcePath = (Resolve-Path -LiteralPath $SourceDir).Path
$safeName = New-DevSafeName $Name
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$snapshotPath = Join-Path $OutputRoot "$stamp-$safeName"

Copy-DevDirectoryFresh -Source $sourcePath -Destination $snapshotPath

$metadata = @(
  "name=$safeName"
  "created=$(Get-Date -Format o)"
  "source=$sourcePath"
  "snapshot=$snapshotPath"
)
[System.IO.File]::WriteAllText((Join-Path $snapshotPath '.mmb4l-patch-snapshot'), (($metadata -join "`n") + "`n"))

Write-Output "Snapshot: $snapshotPath"
