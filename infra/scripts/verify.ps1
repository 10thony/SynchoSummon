#Requires -Version 5.1
<#
.SYNOPSIS
  Run verify-seed-counts.sql against the running Oracle instance.
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

Get-Content (Join-Path $InfraRoot "oracle\verify\verify-seed-counts.sql") -Raw |
    docker compose --env-file .env exec -T oracle `
        sqlplus -s "$appUser/$appPassword@FREEPDB1"
