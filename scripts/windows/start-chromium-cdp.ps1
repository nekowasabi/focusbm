$ErrorActionPreference = 'Stop'
$Port = if ($env:FOCUSBM_CDP_PORT) { [int]$env:FOCUSBM_CDP_PORT } else { 9222 }
$Profile = if ($env:FOCUSBM_CDP_PROFILE) { $env:FOCUSBM_CDP_PROFILE } else { Join-Path $env:LOCALAPPDATA 'focusbm-cdp-profile' }
New-Item -ItemType Directory -Force -Path $Profile | Out-Null
Set-Content -Path (Join-Path $Profile '.focusbm-cdp-profile') -Value 'focusbm CDP opt-in profile marker'

$candidates = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe"
)
$Browser = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Browser) { throw 'Chrome/Edge executable was not found.' }

Start-Process -FilePath $Browser -ArgumentList @(
  "--remote-debugging-port=$Port",
  "--user-data-dir=$Profile",
  "https://example.com/"
)
Write-Host "Started: $Browser"
Write-Host "Endpoint: http://127.0.0.1:$Port"
Write-Host "Profile:  $Profile"
Write-Host "Marker:   $(Join-Path $Profile '.focusbm-cdp-profile')"
