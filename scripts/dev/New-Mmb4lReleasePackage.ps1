param(
  [switch]$SkipBuild,
  [switch]$VerifyOnly
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Get-DevRepoRoot
Assert-DevGitIndexUnlocked $repoRoot

if (-not $VerifyOnly) {
  if (-not $SkipBuild) {
    Invoke-DevCommand -FilePath 'powershell' -ArgumentList @(
      '-ExecutionPolicy', 'Bypass', '-File', '.\scripts\build-mmbasic.ps1'
    ) -WorkingDirectory $repoRoot
  }
  Invoke-DevCommand -FilePath 'powershell' -ArgumentList @(
    '-ExecutionPolicy', 'Bypass', '-File', '.\scripts\package-release.ps1', '-UseBuildBinary'
  ) -WorkingDirectory $repoRoot
}

$required = @(
  'dist\mmbasic-luckfox-lyra-armv7l',
  'dist\mmbasic-luckfox-lyra-release.tar.gz',
  'dist\mmbasic-luckfox-lyra-release.zip',
  'dist\SHA256SUMS'
)
foreach ($path in $required) {
  $full = Join-Path $repoRoot $path
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
    throw "Missing release artifact: $path"
  }
}

$zipPath = Join-Path $repoRoot 'dist\mmbasic-luckfox-lyra-release.zip'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
  $entries = $zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') }
  $expected = @(
    'mmbasic-luckfox-lyra-release/bin/mmbasic',
    'mmbasic-luckfox-lyra-release/bin/mmb4l-run-tests',
    'mmbasic-luckfox-lyra-release/bin/mmb4l-check-basic',
    'mmbasic-luckfox-lyra-release/install-picocalc.sh',
    'mmbasic-luckfox-lyra-release/docs/picocalc-repl-usage.md',
    'mmbasic-luckfox-lyra-release/share/tests/picocalc/'
  )
  foreach ($entry in $expected) {
    if (-not ($entries | Where-Object { $_ -eq $entry -or $_.StartsWith($entry) })) {
      throw "Release ZIP is missing expected entry: $entry"
    }
  }
} finally {
  $zip.Dispose()
}

Write-Output 'Release package validation completed.'
