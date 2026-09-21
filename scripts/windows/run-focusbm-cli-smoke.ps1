$ErrorActionPreference = 'Continue'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Yaml = Join-Path $env:TEMP 'focusbm-manual-test.yml'
$env:FOCUSBM_YAML = $Yaml
$Cli = Join-Path $Root 'artifacts\focusbm-cli\FocusBM.Cli.exe'
if (!(Test-Path $Cli)) { & (Join-Path $PSScriptRoot 'publish-focusbm.ps1') }
Remove-Item $Yaml -ErrorAction SilentlyContinue
& $Cli where
& $Cli sample
& $Cli list
& $Cli config get
notepad.exe
Start-Sleep -Seconds 1
& $Cli restore memo
Write-Host "restore exit=$LASTEXITCODE"
& $Cli save current-notepad "manual saved notepad"
Write-Host "save exit=$LASTEXITCODE"
& $Cli list
