#Requires -Version 5.1
<#
.SYNOPSIS
  Apply optional SQL patches from oracle/patches (e.g. entra mapping, ground ops).
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

$patchDir = Join-Path $InfraRoot "oracle\patches"
$files = Get-ChildItem -Path $patchDir -Filter "*.sql" -File | Sort-Object Name
if (-not $files) {
    Write-Host "No patches in oracle/patches." -ForegroundColor Yellow
    exit 0
}

foreach ($file in $files) {
    Write-Host "Patch $($file.Name)..." -ForegroundColor Cyan
    Get-Content $file.FullName -Raw |
        docker compose --env-file .env exec -T oracle `
            sqlplus -s "$appUser/$appPassword@FREEPDB1"
}

Write-Host "Patches applied." -ForegroundColor Green
