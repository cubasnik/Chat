param(
    [int]$MaxAttempts = 5,
    [int]$DelaySeconds = 5,
    [string]$KeyPath = "$HOME/.ssh/id_ed25519"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $KeyPath)) {
    Write-Error "SSH key not found: $KeyPath"
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

$env:GIT_SSH_COMMAND = "ssh -i $KeyPath -o IdentitiesOnly=yes"

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Write-Host "Push attempt $attempt of $MaxAttempts"

    & git push
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Git push succeeded."
        exit 0
    }

    if ($attempt -lt $MaxAttempts) {
        Write-Warning "Git push failed. Waiting $DelaySeconds second(s) before retry."
        Start-Sleep -Seconds $DelaySeconds
    }
}

Write-Error "Git push failed after $MaxAttempts attempt(s)."
