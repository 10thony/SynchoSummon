#Requires -Version 5.1
<#
.SYNOPSIS
  Tail Oracle container logs (Ctrl+C to stop).
#>
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
docker compose --env-file .env logs -f oracle
