$script = Join-Path $PSScriptRoot 'verify-picocalc-fbdev.ps1'
& $script @args
exit $LASTEXITCODE
