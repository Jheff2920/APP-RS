param(
    [switch]$Build,
    [switch]$SkipDebug,
    [switch]$SkipRelease
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..
. "$PSScriptRoot\docker-helpers.ps1"

$destDir = Join-Path $PWD "inst-apk"
New-Item -ItemType Directory -Force -Path $destDir | Out-Null

$debugSrc = Join-Path $PWD "build\app\outputs\flutter-apk\app-debug.apk"
$releaseSrc = Join-Path $PWD "build\app\outputs\flutter-apk\app-release.apk"
$debugDest = Join-Path $destDir "boleta-print-debug.apk"
$releaseDest = Join-Path $destDir "boleta-print-release-arm64.apk"

$needBuild = $Build -or
    ((-not $SkipDebug) -and -not (Test-Path $debugSrc)) -or
    ((-not $SkipRelease) -and -not (Test-Path $releaseSrc))

if ($needBuild -or $Build) {
    Write-Host "Actualizando dependencias..." -ForegroundColor Cyan
    Invoke-DockerCompose run --rm flutter flutter pub get
}

if (-not $SkipDebug -and ($Build -or -not (Test-Path $debugSrc))) {
    Write-Host "Compilando APK debug (todas las ABIs, util para WSA)..." -ForegroundColor Cyan
    Invoke-DockerCompose run --rm flutter flutter build apk --debug
}

if (-not $SkipRelease -and ($Build -or -not (Test-Path $releaseSrc))) {
    Write-Host "Compilando APK release arm64 (telefono fisico, mas liviano)..." -ForegroundColor Cyan
    Invoke-DockerCompose run --rm flutter flutter build apk --release --target-platform android-arm64
}

if (-not $SkipDebug) {
    if (-not (Test-Path $debugSrc)) {
        throw "No se genero el APK debug en $debugSrc"
    }
    Copy-Item $debugSrc $debugDest -Force
    # Compatibilidad con nombre anterior
    Copy-Item $debugSrc (Join-Path $destDir "hello-world-app.apk") -Force
    $dbgSize = [math]::Round((Get-Item $debugDest).Length / 1MB, 1)
    Write-Host "Debug:   $debugDest ($dbgSize MB)" -ForegroundColor Green
}

if (-not $SkipRelease) {
    if (-not (Test-Path $releaseSrc)) {
        throw "No se genero el APK release en $releaseSrc"
    }
    Copy-Item $releaseSrc $releaseDest -Force
    $relSize = [math]::Round((Get-Item $releaseDest).Length / 1MB, 1)
    Write-Host "Release: $releaseDest ($relSize MB)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Uso:" -ForegroundColor Cyan
Write-Host "  Telefono fisico -> boleta-print-release-arm64.apk"
Write-Host "  WSA / pruebas   -> boleta-print-debug.apk"
