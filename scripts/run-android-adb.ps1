param(
    [string]$ApplicationId = "com.example.hello_world_app"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..
. "$PSScriptRoot\docker-helpers.ps1"

function Find-Adb {
    $wingetAdb = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Google.PlatformTools*" `
        -Recurse -Filter adb.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName

    $paths = @()
    if ($wingetAdb) { $paths += $wingetAdb }
    $paths += @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "C:\Android\platform-tools\adb.exe"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) { return $path }
    }

    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    throw "ADB no encontrado. Ejecuta .\scripts\install-prereqs.ps1"
}

Write-Host "Compilando APK debug..." -ForegroundColor Cyan
Invoke-DockerCompose run --rm flutter flutter pub get
Invoke-DockerCompose run --rm flutter flutter build apk --debug

$apk = Join-Path $PWD "build\app\outputs\flutter-apk\app-debug.apk"
if (-not (Test-Path $apk)) {
    throw "No se genero el APK en $apk"
}

$adb = Find-Adb
Write-Host "Conectando ADB al WSA..." -ForegroundColor Cyan
& $adb connect "127.0.0.1:58526" | Out-Null
& $adb devices -l

Write-Host "Instalando en dispositivo Android..." -ForegroundColor Cyan
& $adb install -r $apk

Write-Host "Abriendo la app..." -ForegroundColor Cyan
& $adb shell am start -n "$ApplicationId/.MainActivity"

Write-Host "Listo." -ForegroundColor Green
