param(
  [switch]$SkipChromeRun,
  [switch]$SkipWebBuild
)

$ErrorActionPreference = 'Stop'

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [scriptblock]$Command
  )
  Write-Host "==> $Name"
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
}

Invoke-Step -Name 'flutter pub get' -Command { flutter pub get }
Invoke-Step -Name 'flutter analyze' -Command { flutter analyze }
Invoke-Step -Name 'flutter test' -Command { flutter test }

if (-not $SkipWebBuild) {
  Invoke-Step -Name 'flutter build web' -Command { flutter build web }
}

if (-not $SkipChromeRun) {
  Invoke-Step -Name 'flutter run -d chrome --no-resident' -Command {
    flutter run -d chrome --no-resident
  }
}

Write-Host '==> Dev smoke checks completed successfully.'
