#Requires -Version 5.1
<#
.SYNOPSIS
  Build (if needed) and start Oracle Free with the aviation NAS seed.
#>
$ErrorActionPreference = "Stop"
$InfraRoot = Split-Path -Parent $PSScriptRoot
Set-Location $InfraRoot

$envFile = Join-Path $InfraRoot ".env"
if (-not (Test-Path $envFile)) {
    Copy-Item (Join-Path $InfraRoot ".env.example") $envFile
    Write-Host "Created infra/.env from .env.example" -ForegroundColor Yellow
}

docker compose --env-file .env up -d --build
Write-Host ""
Write-Host "Oracle is starting. First boot (full NAS seed) often takes 5–15 minutes." -ForegroundColor Cyan
Write-Host "Watch:  .\scripts\logs.ps1"
Write-Host "Verify: .\scripts\verify.ps1   (after healthy)"
Write-Host "SQL:    .\scripts\sql.ps1"
