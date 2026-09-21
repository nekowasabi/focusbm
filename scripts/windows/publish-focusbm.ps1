$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Artifacts = Join-Path $Root 'artifacts'
$CliOut = Join-Path $Artifacts 'focusbm-cli'
$AppOut = Join-Path $Artifacts 'focusbm-app'
$Dist = Join-Path $Artifacts 'dist'
New-Item -ItemType Directory -Force -Path $CliOut, $AppOut, $Dist | Out-Null

dotnet publish (Join-Path $Root 'dotnet\FocusBM.Cli\FocusBM.Cli.csproj') -c Debug -r win-x64 --self-contained false -o $CliOut
dotnet publish (Join-Path $Root 'dotnet\FocusBM.App.Wpf\FocusBM.App.Wpf.csproj') -c Debug -r win-x64 --self-contained false -o $AppOut

$Zip = Join-Path $Dist 'focusbm-win-x64-debug.zip'
Remove-Item $Zip -ErrorAction SilentlyContinue
Compress-Archive -Path $CliOut, $AppOut, (Join-Path $Root 'docs\manual-test-checklist.md') -DestinationPath $Zip
$Hash = Get-FileHash -Algorithm SHA256 $Zip
Set-Content -Path ($Zip + '.sha256') -Value "$($Hash.Hash)  $(Split-Path $Zip -Leaf)"

Write-Host "CLI: $CliOut\FocusBM.Cli.exe"
Write-Host "APP: $AppOut\FocusBM.App.Wpf.exe"
Write-Host "ZIP: $Zip"
Write-Host "SHA256: $($Hash.Hash)"
