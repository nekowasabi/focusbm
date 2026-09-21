$ErrorActionPreference = 'Stop'
$docs = Get-ChildItem -Path docs -Recurse -File -Include *.md | ForEach-Object { Get-Content $_.FullName -Raw }
$text = $docs -join "`n"
$strictReleaseGate = ($env:RELEASE_GATE -eq '1' -or $env:RELEASE_GATE -eq 'true')

if ($text -match 'windows-latest\s+feasibility') {
  throw 'windows-latest must not be called feasibility; use smoke-not-feasibility'
}
if ($text -match 'raw artifact.*repo' -and $text -notmatch 'raw artifacts must stay outside repo') {
  throw 'raw artifact policy is ambiguous'
}

if ($strictReleaseGate) {
  $evidenceDir = Join-Path (Get-Location) 'artifacts\manual-evidence'
  $latest = $null
  if (Test-Path $evidenceDir) {
    $latest = Get-ChildItem -Path $evidenceDir -Filter 'manual-real-windows-*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  }
  if (-not $latest) { throw 'strict release gate requires manual-real-windows evidence JSON under artifacts/manual-evidence' }
  $evidence = Get-Content $latest.FullName -Raw | ConvertFrom-Json
  if ($evidence.status -ne 'pass') { throw "manual-real-windows evidence did not pass: $($latest.FullName)" }
  if (-not $evidence.environment.activeDesktopVerified) { throw 'manual-real-windows evidence did not verify active desktop/session' }
  $required = @('cli-sample','cli-list','app-self-test','cli-restore-memo')
  foreach ($name in $required) {
    $step = $evidence.steps | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $step -or $step.exitCode -ne 0) { throw "required evidence step failed or missing: $name" }
  }
  Write-Host "release evidence lint passed (strict): $($latest.FullName)"
  exit 0
}

if ($text -match 'release-block|evidence-required') {
  Write-Host 'release evidence lint passed in CI-smoke mode; manual evidence may still be required for release'
} else {
  Write-Host 'release evidence lint passed'
}
