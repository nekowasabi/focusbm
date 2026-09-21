$ErrorActionPreference = 'Continue'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$EvidenceDir = Join-Path $Root 'artifacts\manual-evidence'
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$JsonPath = Join-Path $EvidenceDir "manual-real-windows-$Timestamp.json"
$MdPath = Join-Path $EvidenceDir "manual-real-windows-$Timestamp.md"
$Yaml = Join-Path $env:TEMP 'focusbm-manual-test.yml'
$env:FOCUSBM_YAML = $Yaml

& (Join-Path $PSScriptRoot 'publish-focusbm.ps1')
$Cli = Join-Path $Root 'artifacts\focusbm-cli\FocusBM.Cli.exe'
$App = Join-Path $Root 'artifacts\focusbm-app\FocusBM.App.Wpf.exe'

function Run-Step($Name, [scriptblock]$Body) {
  $start = Get-Date
  $outFile = Join-Path $EvidenceDir "$Timestamp-$Name.out.txt"
  $errFile = Join-Path $EvidenceDir "$Timestamp-$Name.err.txt"
  try {
    & $Body > $outFile 2> $errFile
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
    return [ordered]@{ name=$Name; exitCode=$code; status=($(if ($code -eq 0) {'pass'} else {'fail'})); stdout=$outFile; stderr=$errFile; started=$start.ToString('o'); finished=(Get-Date).ToString('o') }
  } catch {
    Set-Content -Path $errFile -Value $_.Exception.Message
    return [ordered]@{ name=$Name; exitCode=99; status='error'; stdout=$outFile; stderr=$errFile; started=$start.ToString('o'); finished=(Get-Date).ToString('o') }
  }
}

$steps = @()
Remove-Item $Yaml -ErrorAction SilentlyContinue
$steps += Run-Step 'cli-where' { & $Cli where }
$steps += Run-Step 'cli-sample' { & $Cli sample }
$steps += Run-Step 'cli-list' { & $Cli list }
$steps += Run-Step 'app-self-test' { & $App --self-test }

# Notepad activation smoke
$np = Start-Process -FilePath 'notepad.exe' -PassThru
Start-Sleep -Seconds 1
$steps += Run-Step 'cli-restore-memo' { & $Cli restore memo }
$steps += Run-Step 'cli-save-current' { & $Cli save current-notepad 'manual saved notepad' }
try { Stop-Process -Id $np.Id -ErrorAction SilentlyContinue } catch {}

# Optional capability probes: do not fail whole evidence if disabled/unavailable.
$steps += Run-Step 'cli-tmux-list' { & $Cli tmux-list }
$steps += Run-Step 'cli-config-get' { & $Cli config get }

$sessionName = $env:SESSIONNAME
$os = Get-CimInstance Win32_OperatingSystem
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($user)
$isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
$summaryStatus = if (($steps | Where-Object { $_.name -in @('cli-sample','cli-list','app-self-test','cli-restore-memo') -and $_.exitCode -ne 0 }).Count -eq 0) { 'pass' } else { 'fail' }

$result = [ordered]@{
  kind = 'manual-real-windows-evidence'
  status = $summaryStatus
  timestamp = (Get-Date).ToString('o')
  yaml = $Yaml
  environment = [ordered]@{
    osCaption = $os.Caption
    osVersion = $os.Version
    buildNumber = $os.BuildNumber
    sessionName = $sessionName
    user = $user.Name
    isAdmin = $isAdmin
    activeDesktopVerified = ($sessionName -and $sessionName -ne 'Services')
  }
  artifacts = [ordered]@{
    cli = $Cli
    app = $App
  }
  steps = $steps
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $JsonPath -Encoding UTF8
@"
# manual-real-windows evidence $Timestamp

- Status: $summaryStatus
- OS: $($os.Caption) $($os.Version) build $($os.BuildNumber)
- Session: $sessionName
- User: $($user.Name)
- Admin: $isAdmin
- YAML: $Yaml

## Steps
$(($steps | ForEach-Object { "- $($_.name): $($_.status) (exit=$($_.exitCode))" }) -join "`n")

Raw stdout/stderr files are stored next to this summary under artifacts/manual-evidence and must not be committed if they contain private data.
"@ | Set-Content -Path $MdPath -Encoding UTF8

Write-Host "Evidence JSON: $JsonPath"
Write-Host "Evidence MD:   $MdPath"
Write-Host "Status:        $summaryStatus"
exit ($(if ($summaryStatus -eq 'pass') {0} else {1}))
