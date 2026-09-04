$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..
. "$PSScriptRoot\docker-helpers.ps1"

Write-Host "Construyendo imagen Docker..." -ForegroundColor Cyan
Invoke-DockerCompose build

if (-not (Test-Path "android")) {
    Write-Host "Generando proyecto Flutter..." -ForegroundColor Cyan
    Invoke-DockerCompose run --rm flutter flutter create . `
        --org com.example `
        --project-name hello_world_app `
        --platforms android,ios,web
}

Write-Host "Actualizando dependencias..." -ForegroundColor Cyan
Invoke-DockerCompose run --rm flutter flutter pub get

Write-Host "Proyecto listo." -ForegroundColor Green
