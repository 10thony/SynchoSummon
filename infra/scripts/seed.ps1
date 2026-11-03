#Requires -Version 5.1
<#
.SYNOPSIS
  Re-apply seed scripts (09a+) against an already-initialized database.
  DDL (01–09) is skipped — use reset.ps1 for a full rebuild.
#>
$ErrorActionPreference = "Stop"
$InfraRoot = Split-Path -Parent $PSScriptRoot
Set-Location $InfraRoot

function Get-DotEnvValue {
    param([string]$Key)
    $line = Get-Content (Join-Path $InfraRoot ".env") |
        Where-Object { $_ -match "^\s*$Key\s*=" } |
        Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -split "=", 2)[1].Trim().Trim('"').Trim("'")
}

$appUser = Get-DotEnvValue "ORACLE_APP_USER"
if (-not $appUser) { $appUser = "nas_sim" }
$appPassword = Get-DotEnvValue "ORACLE_APP_PASSWORD"
if (-not $appPassword) { throw "ORACLE_APP_PASSWORD missing in infra/.env" }

$health = docker inspect --format="{{.State.Health.Status}}" syncengine-oracle 2>$null
if ($health -ne "healthy") {
    throw "Oracle is not healthy (status=$health). Start with .\scripts\up.ps1 and wait."
}

$initDir = Join-Path $InfraRoot "oracle\init"
# Seeds only: 09a/09b then 100–126 (sorted)
$files = Get-ChildItem -Path $initDir -Filter "*.sql" -File |
    Where-Object { $_.Name -match '^(09[a-z]_|1\d{2}_)' } |
    Sort-Object Name

foreach ($file in $files) {
    Write-Host "Applying $($file.Name)..." -ForegroundColor Cyan
    Get-Content $file.FullName -Raw |
        docker compose --env-file .env exec -T oracle `
            sqlplus -s "$appUser/$appPassword@FREEPDB1"
    if ($LASTEXITCODE -ne 0) { throw "Failed on $($file.Name)" }
}

Write-Host "Seed re-apply finished. Run .\scripts\verify.ps1" -ForegroundColor Green
