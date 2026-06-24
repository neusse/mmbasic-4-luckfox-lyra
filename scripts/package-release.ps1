param(
  [string]$OutputDir = 'dist',
  [string]$PackageName = 'mmbasic-luckfox-lyra-release',
  [switch]$UseBuildBinary
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$outDir = Join-Path $repoRoot $OutputDir
$standaloneBinary = Join-Path $outDir 'mmbasic-luckfox-lyra-armv7l'
$buildBinary = Join-Path $repoRoot 'build\mmb4l-luckfox-release\mmbasic'
$sourceRoot = Join-Path $repoRoot 'build\mmb4l-luckfox-source'
$submoduleRoot = Join-Path $repoRoot 'mmb4l'
$targetRunner = Join-Path $repoRoot 'scripts\target\mmb4l-run-tests.sh'
$targetInstaller = Join-Path $repoRoot 'scripts\target\install-picocalc.sh'
$directFbConfig = Join-Path $repoRoot 'scripts\target\directfbrc'
$picocalcTests = Join-Path $repoRoot 'tests\picocalc'

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
  $sourceRoot = $submoduleRoot
}

$examplesDir = Join-Path $sourceRoot 'examples'
$testsDir = Join-Path $sourceRoot 'tests'
$sptoolsDir = Join-Path $sourceRoot 'sptools'

foreach ($path in @($sourceRoot, $examplesDir, $testsDir, $sptoolsDir, $targetRunner, $targetInstaller, $directFbConfig, $picocalcTests)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required release input not found: $path"
  }
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if ($UseBuildBinary -and (Test-Path -LiteralPath $buildBinary -PathType Leaf)) {
  Copy-Item -LiteralPath $buildBinary -Destination $standaloneBinary -Force
} elseif (-not (Test-Path -LiteralPath $standaloneBinary -PathType Leaf)) {
  throw "No binary found. Build first and rerun with -UseBuildBinary, or provide $standaloneBinary."
}

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mmb4l-release-" + [guid]::NewGuid().ToString('N'))
$bundleRoot = Join-Path $workRoot $PackageName

function Copy-DirectoryFresh {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )
  if (Test-Path -LiteralPath $Destination) {
    Remove-Item -LiteralPath $Destination -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
  Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Get-Sha256Lower {
  param([Parameter(Mandatory = $true)][string]$Path)
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

try {
  New-Item -ItemType Directory -Force -Path `
    (Join-Path $bundleRoot 'bin'), `
    (Join-Path $bundleRoot 'etc'), `
    (Join-Path $bundleRoot 'share') | Out-Null

  Copy-Item -LiteralPath $standaloneBinary -Destination (Join-Path $bundleRoot 'bin\mmbasic') -Force
  Copy-Item -LiteralPath $targetRunner -Destination (Join-Path $bundleRoot 'bin\mmb4l-run-tests') -Force
  Copy-Item -LiteralPath $targetInstaller -Destination (Join-Path $bundleRoot 'install-picocalc.sh') -Force
  Copy-Item -LiteralPath $directFbConfig -Destination (Join-Path $bundleRoot 'etc\directfbrc') -Force

  Copy-DirectoryFresh -Source $examplesDir -Destination (Join-Path $bundleRoot 'share\examples')
  Copy-DirectoryFresh -Source $testsDir -Destination (Join-Path $bundleRoot 'share\tests')
  Copy-DirectoryFresh -Source $picocalcTests -Destination (Join-Path $bundleRoot 'share\tests\picocalc')
  Copy-DirectoryFresh -Source $sptoolsDir -Destination (Join-Path $bundleRoot 'share\sptools')
  Get-ChildItem -LiteralPath $bundleRoot -Recurse -File -Filter '*.orig' | Remove-Item -Force

  $bundleReadme = @'
# MMBasic For Luckfox Lyra PicoCalc

This release bundle installs the prebuilt ARMv7 MMBasic binary and the runtime
files needed for the Luckfox Lyra PicoCalc target.

Install on the PicoCalc:

```sh
sh install-picocalc.sh
```

The installer writes:

- `/usr/local/bin/mmbasic`
- `/usr/local/bin/mmb4l-run-tests`
- `/usr/local/share/mmb4l`
- `/etc/directfbrc`
- `/usr/bin/mmbasic` and `/usr/bin/mmb4l-run-tests` symlinks

By default it also applies the proven PicoCalc display workaround:

```sh
chmod 666 /dev/fb0 /dev/tty0
```

Set `MMB4L_APPLY_DEVICE_PERMS=0` to skip that step. Set `MMB4L_RUN_SMOKE=0` to
skip the smoke test at the end of installation.

The test runner uses a 60 second timeout per BASIC test file. Set
`MMB4L_TEST_TIMEOUT=120` to allow slower tests, or `MMB4L_TEST_TIMEOUT=0` to
disable the timeout.

After installing, run:

```sh
mmb4l-run-tests
```
'@
  [System.IO.File]::WriteAllText((Join-Path $bundleRoot 'README.md'), $bundleReadme.Replace("`r`n", "`n"))

  $bundleHashLines = @(
    "$(Get-Sha256Lower (Join-Path $bundleRoot 'bin\mmbasic'))  bin/mmbasic"
    "$(Get-Sha256Lower (Join-Path $bundleRoot 'bin\mmb4l-run-tests'))  bin/mmb4l-run-tests"
    "$(Get-Sha256Lower (Join-Path $bundleRoot 'etc\directfbrc'))  etc/directfbrc"
    "$(Get-Sha256Lower (Join-Path $bundleRoot 'install-picocalc.sh'))  install-picocalc.sh"
  )
  [System.IO.File]::WriteAllText((Join-Path $bundleRoot 'SHA256SUMS'), (($bundleHashLines -join "`n") + "`n"))

  $tarArchive = Join-Path $outDir "$PackageName.tar.gz"
  $zipArchive = Join-Path $outDir "$PackageName.zip"
  foreach ($archive in @($tarArchive, $zipArchive)) {
    if (Test-Path -LiteralPath $archive) {
      Remove-Item -LiteralPath $archive -Force
    }
  }
  tar -czf $tarArchive -C $workRoot $PackageName
  if ($LASTEXITCODE -ne 0) {
    throw "tar failed with exit code $LASTEXITCODE"
  }
  Compress-Archive -Path $bundleRoot -DestinationPath $zipArchive -CompressionLevel Optimal

  $distHashLines = @(
    "$(Get-Sha256Lower $standaloneBinary)  mmbasic-luckfox-lyra-armv7l"
    "$(Get-Sha256Lower $tarArchive)  $PackageName.tar.gz"
    "$(Get-Sha256Lower $zipArchive)  $PackageName.zip"
  )
  [System.IO.File]::WriteAllText((Join-Path $outDir 'SHA256SUMS'), (($distHashLines -join "`n") + "`n"))

  Write-Output "Wrote $standaloneBinary"
  Write-Output "Wrote $tarArchive"
  Write-Output "Wrote $zipArchive"
  Write-Output "Wrote $(Join-Path $outDir 'SHA256SUMS')"
} finally {
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  }
}
