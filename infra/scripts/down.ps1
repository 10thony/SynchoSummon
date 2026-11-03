#Requires -Version 5.1
<#
.SYNOPSIS
  Stop the Oracle stack (keeps the data volume).
#>
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
docker compose --env-file .env down
