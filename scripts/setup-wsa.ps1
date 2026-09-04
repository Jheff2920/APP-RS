param(
    [int]$Port = 58526
)

$ErrorActionPreference = "Stop"

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

$adb = Find-Adb
Write-Host "Conectando ADB al WSA en 127.0.0.1:$Port ..." -ForegroundColor Cyan
& $adb connect "127.0.0.1:$Port"
& $adb devices -l
