$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Yaml = Join-Path $env:TEMP 'focusbm-manual-test.yml'
$env:FOCUSBM_YAML = $Yaml
$Cli = Join-Path $Root 'artifacts\focusbm-cli\FocusBM.Cli.exe'
$App = Join-Path $Root 'artifacts\focusbm-app\FocusBM.App.Wpf.exe'

if (!(Test-Path $Cli) -or !(Test-Path $App)) {
  & (Join-Path $PSScriptRoot 'publish-focusbm.ps1')
}

if (!(Test-Path $Yaml)) {
  & $Cli sample
}

Write-Host "FOCUSBM_YAML=$Yaml"
Write-Host "Running app self-test..."
& $App --self-test
if ($LASTEXITCODE -ne 0) { throw "App self-test failed: $LASTEXITCODE" }
Write-Host "Starting focusBM app..."
Start-Process -FilePath $App -WorkingDirectory (Split-Path $App)
