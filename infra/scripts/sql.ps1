#Requires -Version 5.1
<#
.SYNOPSIS
  Interactive SQL*Plus as the app user (nas_sim) against FREEPDB1.
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

docker compose --env-file .env exec oracle `
    sqlplus "$appUser/$appPassword@FREEPDB1"
