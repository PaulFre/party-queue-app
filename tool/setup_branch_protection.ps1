param(
  [Parameter(Mandatory = $true)]
  [string]$Owner,
  [Parameter(Mandatory = $true)]
  [string]$Repo,
  [string]$ConfigPath = ".github/branch-protection.json",
  [string]$Token = $env:GITHUB_TOKEN
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Token)) {
  throw "Missing GitHub token. Set GITHUB_TOKEN env var or pass -Token."
}

if (-not (Test-Path $ConfigPath)) {
  throw "Config not found at '$ConfigPath'."
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$branch = $config.branch
if ([string]::IsNullOrWhiteSpace($branch)) {
  $branch = "main"
}

$requiredChecks = @($config.required_status_checks)
if ($requiredChecks.Count -eq 0) {
  throw "Config must define at least one required status check."
}

$payload = @{
  required_status_checks = @{
    strict = $true
    contexts = $requiredChecks
  }
  enforce_admins = [bool]$config.enforce_admins
  required_pull_request_reviews = @{
    dismiss_stale_reviews = [bool]$config.dismiss_stale_reviews
    require_code_owner_reviews = $false
    required_approving_review_count = [int]$config.required_approving_review_count
  }
  restrictions = $null
  required_linear_history = [bool]$config.required_linear_history
  required_conversation_resolution = [bool]$config.required_conversation_resolution
  allow_force_pushes = $false
  allow_deletions = $false
  block_creations = $false
  lock_branch = $false
  allow_fork_syncing = $true
} | ConvertTo-Json -Depth 10

$uri = "https://api.github.com/repos/$Owner/$Repo/branches/$branch/protection"
$headers = @{
  Authorization = "Bearer $Token"
  Accept = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2022-11-28"
}

Write-Host "Applying branch protection for $Owner/$Repo ($branch)..."
Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $payload -ContentType "application/json" | Out-Null
Write-Host "Branch protection applied successfully."
