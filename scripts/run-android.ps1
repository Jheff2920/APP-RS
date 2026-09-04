param(
    [string]$ApplicationId = "com.example.hello_world_app",
    [switch]$UseAdb,
    [string]$PacmanPath = "C:\Program Files\WSA PacMan\WSA-pacman.exe"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

if ($UseAdb) {
    & "$PSScriptRoot\run-android-adb.ps1" -ApplicationId $ApplicationId
    exit $LASTEXITCODE
}

& "$PSScriptRoot\install-pacman.ps1" -Build -PacmanPath $PacmanPath
