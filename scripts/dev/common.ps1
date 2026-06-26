$ErrorActionPreference = 'Stop'

function Get-DevRepoRoot {
  return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}

function Assert-DevGitIndexUnlocked {
  param([string]$RepoRoot = (Get-DevRepoRoot))

  $lockPath = Join-Path $RepoRoot '.git\index.lock'
  if (Test-Path -LiteralPath $lockPath) {
    throw "Git index lock exists: $lockPath. Stop other git work, then remove it only after confirming no git process is active."
  }
}

function Invoke-DevCommand {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [string]$WorkingDirectory = (Get-DevRepoRoot)
  )

  Push-Location $WorkingDirectory
  try {
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
      throw "$FilePath $($ArgumentList -join ' ') failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
}

function New-DevSafeName {
  param([Parameter(Mandatory = $true)][string]$Name)

  $safe = $Name.Trim().ToLowerInvariant() -replace '[^a-z0-9._-]+', '-'
  $safe = $safe.Trim('-')
  if (-not $safe) { throw 'Name must contain at least one letter or number.' }
  return $safe
}

function New-DevLogDirectory {
  param(
    [string]$Name,
    [string]$RepoRoot = (Get-DevRepoRoot)
  )

  $safeName = New-DevSafeName $Name
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $path = Join-Path $RepoRoot "logs\dev-workflow\$stamp-$safeName"
  New-Item -ItemType Directory -Force -Path $path | Out-Null
  return $path
}

function Get-NextMmb4lPatchNumber {
  param([string]$RepoRoot = (Get-DevRepoRoot))

  $patchDir = Join-Path $RepoRoot 'patches\mmb4l'
  $max = 0
  Get-ChildItem -LiteralPath $patchDir -Filter '*.patch' -File | ForEach-Object {
    if ($_.Name -match '^(\d{4})-') {
      $num = [int]$matches[1]
      if ($num -gt $max) { $max = $num }
    }
  }
  return $max + 1
}

function Format-Mmb4lPatchName {
  param(
    [Parameter(Mandatory = $true)][int]$Number,
    [Parameter(Mandatory = $true)][string]$Name
  )

  return ('{0:d4}-{1}.patch' -f $Number, (New-DevSafeName $Name))
}

function Copy-DevDirectoryFresh {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "Source directory not found: $Source"
  }
  if (Test-Path -LiteralPath $Destination) {
    Remove-Item -LiteralPath $Destination -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
  Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Invoke-DevLoggedCommand {
  param(
    [Parameter(Mandatory = $true)][string]$LogPath,
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [string]$WorkingDirectory = (Get-DevRepoRoot)
  )

  function ConvertTo-DevCommandLineArgument {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Argument)

    if ($Argument -notmatch '[\s"]') { return $Argument }

    $result = '"'
    $backslashes = 0
    foreach ($char in $Argument.ToCharArray()) {
      if ($char -eq '\') {
        $backslashes++
      } elseif ($char -eq '"') {
        $result += ('\' * (($backslashes * 2) + 1))
        $result += '"'
        $backslashes = 0
      } else {
        if ($backslashes -gt 0) {
          $result += ('\' * $backslashes)
          $backslashes = 0
        }
        $result += $char
      }
    }
    if ($backslashes -gt 0) {
      $result += ('\' * ($backslashes * 2))
    }
    $result += '"'
    return $result
  }

  Push-Location $WorkingDirectory
  try {
    "COMMAND: $FilePath $($ArgumentList -join ' ')" | Tee-Object -FilePath $LogPath -Append
    $tempOutput = [System.IO.Path]::GetTempFileName()
    $tempError = [System.IO.Path]::GetTempFileName()
    try {
      $argumentText = ($ArgumentList | ForEach-Object { ConvertTo-DevCommandLineArgument $_ }) -join ' '
      $process = Start-Process -FilePath $FilePath `
        -ArgumentList $argumentText `
        -WorkingDirectory $WorkingDirectory `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $tempOutput `
        -RedirectStandardError $tempError
      $exitCode = $process.ExitCode
      if ((Get-Item -LiteralPath $tempOutput).Length -gt 0) {
        Get-Content -LiteralPath $tempOutput | Tee-Object -FilePath $LogPath -Append
      }
      if ((Get-Item -LiteralPath $tempError).Length -gt 0) {
        Get-Content -LiteralPath $tempError | Tee-Object -FilePath $LogPath -Append
      }
    } finally {
      Remove-Item -LiteralPath $tempOutput -Force -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath $tempError -Force -ErrorAction SilentlyContinue
    }
    if ($exitCode -ne 0) {
      throw "$FilePath $($ArgumentList -join ' ') failed with exit code $exitCode. See $LogPath"
    }
  } finally {
    Pop-Location
  }
}
