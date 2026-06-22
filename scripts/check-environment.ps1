$ErrorActionPreference = 'Continue'

function Write-Check {
  param(
    [string]$Name,
    [bool]$Ok,
    [string]$Detail = ''
  )

  $status = if ($Ok) { 'OK' } else { 'MISSING' }
  if ($Detail) {
    Write-Output ("[{0}] {1} - {2}" -f $status, $Name, $Detail)
  } else {
    Write-Output ("[{0}] {1}" -f $status, $Name)
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function ConvertTo-WslPath {
  param([string]$WindowsPath)

  $resolved = (Resolve-Path -LiteralPath $WindowsPath).Path
  $drive = $resolved.Substring(0, 1).ToLowerInvariant()
  $rest = $resolved.Substring(2).Replace('\', '/')
  return "/mnt/$drive$rest"
}

$git = Get-Command git -ErrorAction SilentlyContinue
Write-Check 'git executable' ([bool]$git) ($(if ($git) { $git.Source } else { '' }))

if ($git) {
  $inside = git rev-parse --is-inside-work-tree 2>$null
  Write-Check 'root git repository' ($inside -eq 'true') $repoRoot

  $submoduleStatus = git submodule status --recursive 2>$null
  Write-Check 'submodule status' ($LASTEXITCODE -eq 0 -and $submoduleStatus) ($submoduleStatus -join '; ')

  $mmb4lRemote = git -C .\mmb4l remote get-url origin 2>$null
  Write-Check 'mmb4l upstream remote' ($mmb4lRemote -eq 'https://github.com/thwill1000/mmb4l.git') $mmb4lRemote

  $mmb4lGitDir = git -C .\mmb4l rev-parse --git-dir 2>$null
  if ($mmb4lGitDir -and -not [System.IO.Path]::IsPathRooted($mmb4lGitDir)) {
    $mmb4lGitDir = Join-Path (Join-Path $repoRoot 'mmb4l') $mmb4lGitDir
  }
  $mmb4lShallow = if ($mmb4lGitDir) { Test-Path -LiteralPath (Join-Path $mmb4lGitDir 'shallow') } else { $true }
  Write-Check 'mmb4l full clone' (-not $mmb4lShallow) 'no .git\shallow file expected'

  $sptoolsGitDir = git -C .\mmb4l\sptools rev-parse --git-dir 2>$null
  if ($sptoolsGitDir -and -not [System.IO.Path]::IsPathRooted($sptoolsGitDir)) {
    $sptoolsGitDir = Join-Path (Join-Path $repoRoot 'mmb4l\sptools') $sptoolsGitDir
  }
  $sptoolsShallow = if ($sptoolsGitDir) { Test-Path -LiteralPath (Join-Path $sptoolsGitDir 'shallow') } else { $true }
  Write-Check 'sptools full clone' (-not $sptoolsShallow) 'no .git\modules\sptools\shallow file expected'
}

$adb = Get-Command adb -ErrorAction SilentlyContinue
$knownAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$adbPath = if ($adb) { $adb.Source } elseif (Test-Path -LiteralPath $knownAdb) { $knownAdb } else { '' }
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$adbDir = if ($adbPath) { Split-Path -Parent $adbPath } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools' }
$userPathHasAdb = ($userPath -split ';') -contains $adbDir
Write-Check 'adb executable' ([bool]$adbPath) ($(if ($adbPath) { $adbPath } else { 'run docs/setup/windows-adb.md' }))
Write-Check 'adb directory in user PATH' $userPathHasAdb $adbDir

if ($adbPath) {
  $adbVersion = & $adbPath version 2>$null | Select-Object -First 1
  Write-Check 'adb version' ($LASTEXITCODE -eq 0) $adbVersion

  $adbDevices = & $adbPath devices -l 2>$null
  $hasDevice = ($adbDevices | Select-String -Pattern '\bdevice\b' -Quiet)
  Write-Check 'adb connected device' $hasDevice (($adbDevices -join ' ') -replace '\s+', ' ')
}

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
Write-Check 'wsl executable' ([bool]$wsl) ($(if ($wsl) { $wsl.Source } else { '' }))

if ($wsl) {
  $ubuntuProbe = wsl.exe -d Ubuntu-22.04 -- sh -lc 'printf ok' 2>$null
  $hasUbuntu = ($ubuntuProbe -eq 'ok')
  Write-Check 'WSL Ubuntu-22.04 distro' $hasUbuntu 'probe: wsl.exe -d Ubuntu-22.04 -- sh -lc "printf ok"'

  $wslRepo = ConvertTo-WslPath $repoRoot
  $toolchain = if ($wslRepo) {
    wsl.exe -d Ubuntu-22.04 -- bash -lc "cd '$wslRepo' && bash scripts/find-wsl-toolchain.sh" 2>$null
  } else {
    @()
  }
  $ccLine = $toolchain | Where-Object { $_ -like 'LUCKFOX_CC=*' } | Select-Object -First 1
  $targetLine = $toolchain | Where-Object { $_ -like 'LUCKFOX_TARGET=*' } | Select-Object -First 1
  $versionLine = $toolchain | Where-Object { $_ -like 'LUCKFOX_GCC_VERSION=*' } | Select-Object -First 1

  Write-Check 'WSL Luckfox SDK toolchain' ([bool]$ccLine) ($(if ($ccLine) { $ccLine.Substring('LUCKFOX_CC='.Length) } else { 'run scripts/find-wsl-toolchain.sh in WSL' }))

  if ($targetLine) {
    $target = $targetLine.Substring('LUCKFOX_TARGET='.Length)
    Write-Check 'WSL compiler target' ($target -eq 'arm-buildroot-linux-gnueabihf') $target
  }

  if ($versionLine) {
    Write-Check 'WSL compiler version' $true ($versionLine.Substring('LUCKFOX_GCC_VERSION='.Length))
  }
}
