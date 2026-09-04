# Instala prerrequisitos para desarrollo Flutter + Android en Windows.
# Ejecutar como administrador si winget falla por permisos.

$ErrorActionPreference = "Stop"

Write-Host "=== Verificando prerrequisitos ===" -ForegroundColor Cyan

function Test-Command($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

$needsPathRefresh = $false

if (-not (Test-Command "docker")) {
    Write-Host "Docker no encontrado. Instalando Docker Desktop..." -ForegroundColor Yellow
    winget install --id Docker.DockerDesktop -e --accept-source-agreements --accept-package-agreements
    Write-Host "Reinicia la PC y abre Docker Desktop antes de continuar." -ForegroundColor Yellow
} else {
    Write-Host "OK: Docker instalado" -ForegroundColor Green
}

if (-not (Test-Command "adb")) {
    Write-Host "ADB no encontrado. Instalando Android Platform Tools..." -ForegroundColor Yellow
    winget install --id Google.PlatformTools -e --accept-source-agreements --accept-package-agreements
    $needsPathRefresh = $true
} else {
    Write-Host "OK: ADB instalado" -ForegroundColor Green
}

if ($needsPathRefresh) {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

Write-Host ""
Write-Host "=== Estado final ===" -ForegroundColor Cyan
if (Test-Command "docker") { docker --version } else { Write-Host "Docker: pendiente (reinicia PC)" -ForegroundColor Red }
if (Test-Command "adb") { adb version } else { Write-Host "ADB: no en PATH. Reabre la terminal." -ForegroundColor Red }

Write-Host ""
Write-Host "Siguiente paso: activa Modo desarrollador en WSA y ejecuta .\scripts\setup-wsa.ps1" -ForegroundColor Cyan
