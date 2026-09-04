param(
    [switch]$Release,
    [switch]$InstallOnly,
    [string]$Serial = ""
)

# Pruebas rapidas en el telefono SIN Docker.
# Uso:
#   .\scripts\run-phone.ps1              # flutter run (hot reload)
#   .\scripts\run-phone.ps1 -InstallOnly # build debug + adb install -r
#   .\scripts\run-phone.ps1 -InstallOnly -Serial HA1KL54R
#   .\scripts\run-phone.ps1 -Release     # APK release arm64 + install

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

$flutter = "C:\flutter\bin\flutter.bat"
if (-not (Test-Path $flutter)) {
    throw "Flutter no encontrado en C:\flutter. Instala el SDK local primero."
}

$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$jdk = (Get-ChildItem "C:\Program Files\Microsoft\jdk-17*" -Directory -ErrorAction SilentlyContinue |
    Select-Object -First 1).FullName
if (-not $jdk) { throw "JDK 17 no encontrado (Microsoft OpenJDK)." }

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:JAVA_HOME = $jdk
$env:Path = "C:\flutter\bin;$jdk\bin;$sdk\platform-tools;" + $env:Path

$adb = Join-Path $sdk "platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
    $adb = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Google.PlatformTools*" `
        -Recurse -Filter adb.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1).FullName
}
if (-not $adb) { throw "ADB no encontrado." }

& $adb start-server | Out-Null
$deviceLines = @(& $adb devices | Where-Object { $_ -match "`tdevice$" })
if (-not $deviceLines) {
    throw "No hay telefono conectado por ADB. Activa depuracion USB."
}

$serials = @(
    $deviceLines | ForEach-Object {
        $parts = $_ -split "\s+", 2
        $parts[0]
    }
)
if ($serials.Count -eq 0) {
    throw "No se pudo leer el serial ADB."
}
if ([string]::IsNullOrWhiteSpace($Serial)) {
    $Serial = [string]$serials[0]
} elseif ($serials -notcontains $Serial) {
    Write-Host "Serial $Serial no conectado; usando $($serials[0])" -ForegroundColor Yellow
    $Serial = [string]$serials[0]
}

Write-Host "Dispositivos:" -ForegroundColor Cyan
& $adb devices -l
Write-Host "Usando: $Serial" -ForegroundColor Cyan

if ($InstallOnly -or $Release) {
    if ($Release) {
        Write-Host "Compilando release arm64 (local)..." -ForegroundColor Cyan
        & $flutter build apk --release --target-platform android-arm64
        if ($LASTEXITCODE -ne 0) { throw "flutter build release fallo" }
        $apk = Join-Path $PWD "build\app\outputs\flutter-apk\app-release.apk"
        New-Item -ItemType Directory -Force -Path (Join-Path $PWD "inst-apk") | Out-Null
        Copy-Item $apk (Join-Path $PWD "inst-apk\boleta-print-release-arm64.apk") -Force
    } else {
        Write-Host "Compilando debug (local)..." -ForegroundColor Cyan
        & $flutter build apk --debug
        if ($LASTEXITCODE -ne 0) { throw "flutter build debug fallo" }
        $apk = Join-Path $PWD "build\app\outputs\flutter-apk\app-debug.apk"
        New-Item -ItemType Directory -Force -Path (Join-Path $PWD "inst-apk") | Out-Null
        Copy-Item $apk (Join-Path $PWD "inst-apk\boleta-print-debug.apk") -Force
    }

    Write-Host "Instalando en $Serial ..." -ForegroundColor Cyan
    & $adb -s $Serial install -r $apk
    if ($LASTEXITCODE -ne 0) { throw "adb install fallo" }
    & $adb -s $Serial shell am start -n com.example.hello_world_app/.MainActivity
    Write-Host "Listo." -ForegroundColor Green
    return
}

Write-Host "flutter run en $Serial (hot reload: tecla r)..." -ForegroundColor Cyan
& $flutter run -d $Serial
