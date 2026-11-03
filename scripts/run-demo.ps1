#Requires -Version 5.1
<#
.SYNOPSIS
  Launches Aviation.Server, Aviation.Blazor, and Aviation.Maui for manual SyncEngine demos.

.EXAMPLE
  .\scripts\run-demo.ps1

.EXAMPLE
  .\scripts\run-demo.ps1 -SkipMaui
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$SkipMaui,
    [string]$ServerUrl = "http://localhost:5080",
    [string]$BlazorUrl = "http://localhost:5280"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$ServerProject = Join-Path $Root "apps\Aviation.Server\Aviation.Server.csproj"
$BlazorProject = Join-Path $Root "apps\Aviation.Blazor\Aviation.Blazor.csproj"
$MauiProject = Join-Path $Root "apps\Aviation.Maui\Aviation.Maui.csproj"
$MauiTfm = "net10.0-windows10.0.19041.0"

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

if (-not $SkipBuild) {
    Write-Step "Building Server + Blazor"
    dotnet build $ServerProject --nologo
    if ($LASTEXITCODE -ne 0) { throw "Server build failed." }
    dotnet build $BlazorProject --nologo
    if ($LASTEXITCODE -ne 0) { throw "Blazor build failed." }

    if (-not $SkipMaui) {
        Write-Step "Building MAUI ($MauiTfm)"
        dotnet build $MauiProject -f $MauiTfm --nologo
        if ($LASTEXITCODE -ne 0) { throw "MAUI build failed." }
    }
}

Write-Step "Starting Aviation.Server on $ServerUrl"
$serverArgs = @(
    "run", "--project", $ServerProject, "--no-build", "--no-launch-profile",
    "--urls", $ServerUrl
)
Start-Process -FilePath "dotnet" -ArgumentList $serverArgs -WorkingDirectory $Root

Write-Host "Waiting for server..." -ForegroundColor DarkGray
$deadline = (Get-Date).AddSeconds(45)
$ready = $false
while ((Get-Date) -lt $deadline) {
    try {
        $response = Invoke-WebRequest -Uri $ServerUrl -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
            $ready = $true
            break
        }
    }
    catch {
        Start-Sleep -Milliseconds 500
    }
}
if (-not $ready) {
    Write-Warning "Server did not respond at $ServerUrl within 45s. Continuing anyway."
}
else {
    Write-Host "Server is up." -ForegroundColor Green
}

Write-Step "Starting Aviation.Blazor on $BlazorUrl"
$blazorArgs = @(
    "run", "--project", $BlazorProject, "--no-build", "--no-launch-profile",
    "--urls", $BlazorUrl
)
# Point Blazor at the sync server
$env:SyncEngine__ServerBaseAddress = $ServerUrl
Start-Process -FilePath "dotnet" -ArgumentList $blazorArgs -WorkingDirectory $Root

Start-Sleep -Seconds 3
$telemetryUrl = "$ServerUrl/telemetry"
try {
    Start-Process $telemetryUrl
    Start-Process $BlazorUrl
}
catch {
    Write-Host "Open telemetry: $telemetryUrl" -ForegroundColor Yellow
    Write-Host "Open Blazor manually: $BlazorUrl" -ForegroundColor Yellow
}

if (-not $SkipMaui) {
    Write-Step "Starting Aviation.Maui (Windows)"
    $mauiArgs = @(
        "run", "--project", $MauiProject, "-f", $MauiTfm, "--no-build"
    )
    Start-Process -FilePath "dotnet" -ArgumentList $mauiArgs -WorkingDirectory $Root
}

Write-Host ""
Write-Host "Demo stack launching:" -ForegroundColor Green
Write-Host "  Server    : $ServerUrl"
Write-Host "  Telemetry : $ServerUrl/telemetry"
Write-Host "  Blazor    : $BlazorUrl"
if (-not $SkipMaui) {
    Write-Host "  MAUI      : Windows desktop window"
}
Write-Host ""
Write-Host "Try: add a facility in Blazor or MAUI and watch the other update."
Write-Host "Watch /telemetry for latency, bytes, and payload previews."
Write-Host "Stop processes from their console windows (Ctrl+C) when done."
Write-Host ""
Write-Host "Options: -SkipBuild  -SkipMaui  -ServerUrl <url>  -BlazorUrl <url>"
