#Requires -Version 5.1
<#
.SYNOPSIS
  Tear down Oracle and delete the data volume, then start fresh.
  Re-runs initdb.d scripts on the next boot.
#>
$ErrorActionPreference = "Stop"
$InfraRoot = Split-Path -Parent $PSScriptRoot
Set-Location $InfraRoot

Write-Host "This will DESTROY all local Oracle data (volume syncengine-oracle-data)." -ForegroundColor Yellow
$confirm = Read-Host "Type RESET to continue"
if ($confirm -ne "RESET") {
    Write-Host "Aborted."
    exit 1
}

docker compose --env-file .env down -v
& (Join-Path $PSScriptRoot "up.ps1")
