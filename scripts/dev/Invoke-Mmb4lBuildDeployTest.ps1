param(
  [string[]]$FocusedTests = @(),
  [switch]$ScreenModeFocused,
  [switch]$SkipBuild,
  [switch]$SkipDeploy,
  [switch]$SkipFull,
  [string]$LogDir = ''
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Get-DevRepoRoot
Assert-DevGitIndexUnlocked $repoRoot
if (-not $LogDir) { $LogDir = New-DevLogDirectory -Name 'build-deploy-test' -RepoRoot $repoRoot }
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

if (-not $SkipBuild) {
  Invoke-DevLoggedCommand -LogPath (Join-Path $LogDir 'build.log') `
    -FilePath 'powershell' `
    -ArgumentList @('-ExecutionPolicy', 'Bypass', '-File', '.\scripts\build-mmbasic.ps1') `
    -WorkingDirectory $repoRoot
}

if (-not $SkipDeploy) {
  Invoke-DevLoggedCommand -LogPath (Join-Path $LogDir 'deploy.log') `
    -FilePath 'powershell' `
    -ArgumentList @('-ExecutionPolicy', 'Bypass', '-File', '.\scripts\deploy-mmbasic.ps1') `
    -WorkingDirectory $repoRoot
}

$expandedFocusedTests = @()
foreach ($test in $FocusedTests) {
  foreach ($part in ($test -split ',')) {
    $trimmed = $part.Trim()
    if ($trimmed) { $expandedFocusedTests += $trimmed }
  }
}

$focusedIndex = 0
foreach ($test in $expandedFocusedTests) {
  $focusedIndex++
  $prefix = if ($ScreenModeFocused) { 'MMB4L_PICOCALC_CONSOLE=screen ' } else { '' }
  $quotedTest = $test.Replace("'", "'\''")
  $remote = "${prefix}mmbasic '$quotedTest'; rc=`$?; echo focused_rc:`$rc; exit `$rc"
  Invoke-DevLoggedCommand -LogPath (Join-Path $LogDir ("focused-$focusedIndex.log")) `
    -FilePath 'adb' `
    -ArgumentList @('shell', $remote) `
    -WorkingDirectory $repoRoot
}

if (-not $SkipFull) {
  Invoke-DevLoggedCommand -LogPath (Join-Path $LogDir 'target-tests.log') `
    -FilePath 'adb' `
    -ArgumentList @('shell', 'mmb4l-run-tests --all') `
    -WorkingDirectory $repoRoot
}

Write-Output "Logs: $LogDir"
