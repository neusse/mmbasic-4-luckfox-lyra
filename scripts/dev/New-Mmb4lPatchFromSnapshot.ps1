param(
  [Parameter(Mandatory = $true)][string]$SnapshotDir,
  [Parameter(Mandatory = $true)][string]$Name,
  [string]$SourceDir = '',
  [string]$PatchDir = '',
  [int]$Number = 0,
  [switch]$KeepTemp
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Get-DevRepoRoot
Assert-DevGitIndexUnlocked $repoRoot

if (-not $SourceDir) { $SourceDir = Join-Path $repoRoot 'build\mmb4l-luckfox-source' }
if (-not $PatchDir) { $PatchDir = Join-Path $repoRoot 'patches\mmb4l' }
if ($Number -le 0) { $Number = Get-NextMmb4lPatchNumber $repoRoot }

$snapshotPath = (Resolve-Path -LiteralPath $SnapshotDir).Path
$sourcePath = (Resolve-Path -LiteralPath $SourceDir).Path
$patchDirPath = (Resolve-Path -LiteralPath $PatchDir).Path
$patchName = Format-Mmb4lPatchName -Number $Number -Name $Name
$patchPath = Join-Path $patchDirPath $patchName

if (Test-Path -LiteralPath $patchPath) {
  throw "Patch already exists: $patchPath"
}

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mmb4l-patch-diff-" + [guid]::NewGuid().ToString('N'))
$oldRoot = Join-Path $workRoot 'old'
$newRoot = Join-Path $workRoot 'new'

try {
  Copy-DevDirectoryFresh -Source $snapshotPath -Destination $oldRoot
  Copy-DevDirectoryFresh -Source $sourcePath -Destination $newRoot
  Remove-Item -LiteralPath (Join-Path $oldRoot '.mmb4l-patch-snapshot') -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath (Join-Path $newRoot '.mmb4l-patch-snapshot') -Force -ErrorAction SilentlyContinue

  Push-Location $workRoot
  try {
    $diffLines = & git -c core.autocrlf=false diff --no-index -- old new
    $diffExit = $LASTEXITCODE
  } finally {
    Pop-Location
  }

  if ($diffExit -eq 0) {
    throw "No differences found between snapshot and source."
  }
  if ($diffExit -gt 1) {
    throw "git diff --no-index failed with exit code $diffExit"
  }

  $patchText = ($diffLines -join "`n")
  $patchText = $patchText -replace 'a/old/', 'a/'
  $patchText = $patchText -replace 'b/new/', 'b/'
  $patchText = $patchText -replace '--- old/', '--- a/'
  $patchText = $patchText -replace '\+\+\+ new/', '+++ b/'
  [System.IO.File]::WriteAllText($patchPath, $patchText + "`n")

  Push-Location $oldRoot
  try {
    & git apply --check $patchPath
    if ($LASTEXITCODE -ne 0) {
      throw "Generated patch does not apply cleanly to its snapshot: $patchPath"
    }
  } finally {
    Pop-Location
  }

  Write-Output "Patch: $patchPath"
} finally {
  if (-not $KeepTemp -and (Test-Path -LiteralPath $workRoot)) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  } elseif ($KeepTemp) {
    Write-Output "Temp: $workRoot"
  }
}
