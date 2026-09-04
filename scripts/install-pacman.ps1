param(
    [switch]$Build,
    [string]$PacmanPath = "C:\Program Files\WSA PacMan\WSA-pacman.exe"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..
. "$PSScriptRoot\docker-helpers.ps1"

$apk = Join-Path $PWD "build\app\outputs\flutter-apk\app-debug.apk"

if ($Build -or -not (Test-Path $apk)) {
    Write-Host "Compilando APKs (debug + release)..." -ForegroundColor Cyan
    & "$PSScriptRoot\export-apk.ps1" -Build
}

$destDir = Join-Path $PWD "inst-apk"
$destApk = Join-Path $destDir "boleta-print-debug.apk"
if (-not (Test-Path $destApk)) {
    $destApk = Join-Path $destDir "hello-world-app.apk"
}
if (-not (Test-Path $destApk) -and (Test-Path $apk)) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    Copy-Item $apk $destApk -Force
}
if (-not (Test-Path $destApk)) {
    throw "No se encontro APK debug. Ejecuta .\scripts\export-apk.ps1 -Build"
}
Write-Host "APK para PacMan (debug/WSA): $destApk" -ForegroundColor Green

if (-not (Test-Path $PacmanPath)) {
    throw "WSA PacMan no encontrado en $PacmanPath. Instalalo desde https://github.com/alesimula/wsa_pacman/releases"
}

Write-Host ""
Write-Host "IMPORTANTE: PacMan solo habilita Install si WSA esta conectado." -ForegroundColor Yellow
Write-Host "Si el boton Install esta gris, ejecuta primero:" -ForegroundColor Yellow
Write-Host "  .\scripts\fix-wsa-connection.ps1" -ForegroundColor Yellow
Write-Host ""

# Abrir PacMan principal para verificar estado (Connected = verde)
Start-Process -FilePath $PacmanPath
Start-Sleep -Seconds 2

Write-Host "Abriendo WSA PacMan en modo instalacion:" -ForegroundColor Cyan
Write-Host $destApk
Start-Process -FilePath $PacmanPath -ArgumentList "`"$destApk`""
Write-Host ""
Write-Host "En PacMan debe decir 'Connected' (verde). Si dice Offline/Unauthorized:" -ForegroundColor Yellow
Write-Host "  1. WSA Settings > Developer > activar Modo desarrollador" -ForegroundColor Yellow
Write-Host "  2. Manage developer settings > USB debugging ON" -ForegroundColor Yellow
Write-Host "  3. Revocar autorizaciones y volver a activar USB debugging" -ForegroundColor Yellow
Write-Host "  4. Aceptar el popup 'Allow USB debugging' con 'Always allow'" -ForegroundColor Yellow
Write-Host ""
Write-Host "Luego pulsa Install en PacMan." -ForegroundColor Green
