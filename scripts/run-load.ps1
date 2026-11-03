#Requires -Version 5.1
<#
.SYNOPSIS
  Rebuilds Aviation.Server if needed and fires SyncEngine.LoadGen packages.

.EXAMPLE
  .\scripts\run-load.ps1
  .\scripts\run-load.ps1 -Profile hard
  .\scripts\run-load.ps1 -Profile crush -Concurrency 12
#>
[CmdletBinding()]
param(
    [ValidateSet("smoke", "hard", "crush")]
    [string]$Profile = "crush",
    [int]$Concurrency = 8,
    [string]$ServerUrl = "http://localhost:5080",
    [switch]$SkipServerRestart
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "==> Building server + loadgen" -ForegroundColor Cyan
dotnet build apps/Aviation.Server/Aviation.Server.csproj --nologo
if ($LASTEXITCODE -ne 0) { throw "Server build failed" }
dotnet build tools/SyncEngine.LoadGen/SyncEngine.LoadGen.csproj --nologo
if ($LASTEXITCODE -ne 0) { throw "LoadGen build failed" }

if (-not $SkipServerRestart) {
    Write-Host "==> Restarting Aviation.Server on $ServerUrl" -ForegroundColor Cyan
    Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" |
        Where-Object { $_.CommandLine -match 'Aviation\.Server' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

    Start-Sleep -Seconds 1
    Start-Process -FilePath "dotnet" -ArgumentList @(
        "run", "--project", "$Root\apps\Aviation.Server\Aviation.Server.csproj",
        "--no-build", "--no-launch-profile", "--urls", $ServerUrl
    ) -WorkingDirectory $Root -WindowStyle Minimized

    $deadline = (Get-Date).AddSeconds(45)
    do {
        Start-Sleep -Milliseconds 600
        try {
            $r = Invoke-WebRequest "$ServerUrl/" -UseBasicParsing -TimeoutSec 2
            if ($r.StatusCode -eq 200) { break }
        } catch { }
    } while ((Get-Date) -lt $deadline)
}

Write-Host "==> Opening telemetry" -ForegroundColor Cyan
Start-Process "$ServerUrl/telemetry"

Write-Host "==> Firing profile=$Profile concurrency=$Concurrency" -ForegroundColor Cyan
dotnet run --project tools/SyncEngine.LoadGen --no-build -- `
    --server $ServerUrl `
    --profile $Profile `
    --concurrency $Concurrency

Write-Host ""
Write-Host "Done. Refresh MAUI/Blazor and watch $ServerUrl/telemetry" -ForegroundColor Green
