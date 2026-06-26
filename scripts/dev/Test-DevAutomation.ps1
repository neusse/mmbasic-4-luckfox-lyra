param()

. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Get-DevRepoRoot
$scripts = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File
foreach ($script in $scripts) {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) {
    $message = ($errors | ForEach-Object { "$($_.Extent.StartLineNumber): $($_.Message)" }) -join '; '
    throw "PowerShell parse failed for $($script.Name): $message"
  }
}

$root = Join-Path $repoRoot 'tmp\dev-automation-selftest'
Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Join-Path $root 'snapshot\src'), (Join-Path $root 'source\src'), (Join-Path $root 'patches') | Out-Null
[System.IO.File]::WriteAllText((Join-Path $root 'snapshot\src\example.c'), "int value(void) { return 1; }`n")
[System.IO.File]::WriteAllText((Join-Path $root 'source\src\example.c'), "int value(void) { return 2; }`n")

Invoke-DevCommand -FilePath 'powershell' -ArgumentList @(
  '-ExecutionPolicy', 'Bypass',
  '-File', '.\scripts\dev\New-Mmb4lPatchFromSnapshot.ps1',
  '-SnapshotDir', (Join-Path $root 'snapshot'),
  '-SourceDir', (Join-Path $root 'source'),
  '-PatchDir', (Join-Path $root 'patches'),
  '-Name', 'selftest',
  '-Number', '9999'
) -WorkingDirectory $repoRoot

$patch = Join-Path $root 'patches\9999-selftest.patch'
if (-not (Test-Path -LiteralPath $patch -PathType Leaf)) {
  throw "Self-test patch was not created: $patch"
}

Invoke-DevCommand -FilePath 'git' -ArgumentList @('-C', (Join-Path $root 'snapshot'), 'apply', '--check', $patch) -WorkingDirectory $repoRoot

$logPath = Join-Path $root 'logged-stderr.log'
Invoke-DevLoggedCommand -LogPath $logPath `
  -FilePath 'powershell' `
  -ArgumentList @('-NoProfile', '-Command', "Write-Error 'stderr sample' -ErrorAction Continue; Write-Output 'stdout sample'; exit 0") `
  -WorkingDirectory $repoRoot
if (-not (Select-String -LiteralPath $logPath -Pattern 'stderr sample' -Quiet)) {
  throw "Logged command self-test did not capture stderr output."
}
if (-not (Select-String -LiteralPath $logPath -Pattern 'stdout sample' -Quiet)) {
  throw "Logged command self-test did not capture stdout output."
}

Write-Output 'Dev automation self-test completed.'
