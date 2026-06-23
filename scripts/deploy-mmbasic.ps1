param(
  [string]$InstallBinDir = '/usr/local/bin',
  [string]$PathBinDir = '/usr/bin',
  [string]$InstallShareDir = '/usr/local/share/mmb4l',
  [string]$DirectFbConfigPath = '/etc/directfbrc',
  [string]$RemoteStage = '/tmp/mmb4l-deploy',
  [switch]$SkipSmoke
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$binary = Join-Path $repoRoot 'build\mmb4l-luckfox-release\mmbasic'
$patchedSourceDir = Join-Path $repoRoot 'build\mmb4l-luckfox-source'
$sourceRoot = if (Test-Path -LiteralPath $patchedSourceDir) { $patchedSourceDir } else { Join-Path $repoRoot 'mmb4l' }
$examplesDir = Join-Path $sourceRoot 'examples'
$testsDir = Join-Path $sourceRoot 'tests'
$sptoolsDir = Join-Path $sourceRoot 'sptools'
$targetRunner = Join-Path $repoRoot 'scripts\target\mmb4l-run-tests.sh'
$directFbConfig = Join-Path $repoRoot 'scripts\target\directfbrc'

foreach ($path in @($binary, $examplesDir, $testsDir, $sptoolsDir, $targetRunner, $directFbConfig)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required path not found: $path"
  }
}

$adb = Get-Command adb -ErrorAction SilentlyContinue
$knownAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$adbPath = if ($adb) { $adb.Source } elseif (Test-Path -LiteralPath $knownAdb) { $knownAdb } else { '' }

if (-not $adbPath) {
  throw 'adb.exe was not found. See docs/setup/windows-adb.md.'
}

function Invoke-Adb {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

  & $script:adbPath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "adb $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}

$remoteScript = @"
set -eu
stage='$RemoteStage'
bin_dir='$InstallBinDir'
path_bin_dir='$PathBinDir'
share_dir='$InstallShareDir'
directfb_config_path='$DirectFbConfigPath'

test -f "`$stage/mmbasic"
test -f "`$stage/directfbrc"
test -d "`$stage/share/examples"
test -d "`$stage/share/tests"
test -d "`$stage/share/sptools"
test -f "`$stage/mmb4l-run-tests.sh"

mkdir -p "`$bin_dir" "`$share_dir"
rm -rf "`$share_dir/examples" "`$share_dir/tests" "`$share_dir/sptools"

cp "`$stage/mmbasic" "`$bin_dir/mmbasic"
cp -R "`$stage/share/examples" "`$share_dir/examples"
cp -R "`$stage/share/tests" "`$share_dir/tests"
cp -R "`$stage/share/sptools" "`$share_dir/sptools"
cp "`$stage/mmb4l-run-tests.sh" "`$bin_dir/mmb4l-run-tests"
if [ -n "`$directfb_config_path" ]; then
  mkdir -p "`$(dirname "`$directfb_config_path")"
  cp "`$stage/directfbrc" "`$directfb_config_path"
fi

chmod 755 "`$bin_dir/mmbasic" "`$bin_dir/mmb4l-run-tests"

if [ -n "`$path_bin_dir" ] && [ "`$path_bin_dir" != "`$bin_dir" ]; then
  mkdir -p "`$path_bin_dir"
  ln -sf "`$bin_dir/mmbasic" "`$path_bin_dir/mmbasic"
  ln -sf "`$bin_dir/mmb4l-run-tests" "`$path_bin_dir/mmb4l-run-tests"
fi

"`$bin_dir/mmbasic" --version
"@

$tempInstall = Join-Path ([System.IO.Path]::GetTempPath()) 'mmb4l-install-on-target.sh'
[System.IO.File]::WriteAllText($tempInstall, $remoteScript.Replace("`r`n", "`n"))

try {
  Invoke-Adb shell "rm -rf '$RemoteStage'; mkdir -p '$RemoteStage/share'"
  Invoke-Adb push $binary "$RemoteStage/mmbasic"
  Invoke-Adb push $targetRunner "$RemoteStage/mmb4l-run-tests.sh"
  Invoke-Adb push $directFbConfig "$RemoteStage/directfbrc"
  Invoke-Adb push $tempInstall "$RemoteStage/install.sh"
  Invoke-Adb push $examplesDir "$RemoteStage/share/"
  Invoke-Adb push $testsDir "$RemoteStage/share/"
  Invoke-Adb push $sptoolsDir "$RemoteStage/share/"
  Invoke-Adb shell "sh '$RemoteStage/install.sh'"

  if (-not $SkipSmoke) {
    Invoke-Adb shell "command -v mmbasic; command -v mmb4l-run-tests; mmb4l-run-tests --smoke"
  }

  Write-Output "Installed mmbasic to $InstallBinDir/mmbasic"
  if ($PathBinDir -and ($PathBinDir -ne $InstallBinDir)) {
    Write-Output "Linked mmbasic into $PathBinDir for shell PATH discovery"
  }
  Write-Output "Deployed BASIC examples/tests from $sourceRoot"
  Write-Output "Installed examples/tests/sptools to $InstallShareDir"
  Write-Output "Installed test runner to $InstallBinDir/mmb4l-run-tests"
  if ($DirectFbConfigPath) {
    Write-Output "Installed DirectFB config to $DirectFbConfigPath"
  }
} finally {
  Remove-Item -LiteralPath $tempInstall -Force -ErrorAction SilentlyContinue
}
