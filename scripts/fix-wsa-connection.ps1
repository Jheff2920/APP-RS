# Diagnostica y ayuda a conectar WSA con PacMan/ADB.
$ErrorActionPreference = "Continue"

function Find-Adb {
    $wingetAdb = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Google.PlatformTools*" `
        -Recurse -Filter adb.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($wingetAdb) { return $wingetAdb }
    throw "ADB no encontrado. Ejecuta .\scripts\install-prereqs.ps1"
}

Write-Host "=== Diagnostico WSA + PacMan ===" -ForegroundColor Cyan

$wsa = Get-AppxPackage *WindowsSubsystemForAndroid* -ErrorAction SilentlyContinue
if (-not $wsa) {
    Write-Host "ERROR: WSA no esta instalado." -ForegroundColor Red
    exit 1
}
Write-Host "WSA instalado: $($wsa.Version)" -ForegroundColor Green

Write-Host "`nAbriendo configuracion de WSA..." -ForegroundColor Yellow
Start-Process "shell:AppsFolder\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!SettingsApp"

Write-Host @"

PASOS MANUALES (hazlos en la ventana de WSA que se abrio):

  1. Ve a la pestana "Desarrollador" / "Developer"
  2. Activa "Modo desarrollador"
  3. Pulsa "Administrar configuracion de desarrollador"
  4. Activa "Depuracion USB" / "USB debugging"
  5. Si existe "Revocar autorizaciones de depuracion USB", pulsalo y confirma
  6. Desactiva y vuelve a activar "Depuracion USB"
  7. Debe aparecer un popup pidiendo autorizar ADB -> marca "Permitir siempre" y Allow

"@ -ForegroundColor Yellow

Read-Host "Cuando hayas hecho los pasos, pulsa Enter para probar la conexion"

$adb = Find-Adb
& $adb kill-server 2>$null | Out-Null
& $adb start-server | Out-Null

$ports = @(58526, 5555)
$connected = $false

foreach ($port in $ports) {
    Write-Host "Probando 127.0.0.1:$port ..." -ForegroundColor Cyan
    $result = & $adb connect "127.0.0.1:$port" 2>&1
    Write-Host $result
    $devices = & $adb devices 2>&1
    Write-Host $devices
    if ($devices -match "127.0.0.1:$port\s+device") {
        $connected = $true
        break
    }
    if ($devices -match "unauthorized") {
        Write-Host "Estado: UNAUTHORIZED - acepta el popup de depuracion USB en WSA." -ForegroundColor Red
    }
}

if (-not $connected) {
    Write-Host @"

No se pudo conectar. Prueba tambien:

  - Abre cualquier app de Android en WSA para iniciar el subsistema
  - En WSA Settings, copia la IP:puerto y ejecuta:
      adb connect <IP:PUERTO>
  - Reinicia WSA desde Configuracion > Aplicaciones > WSA > Terminar > volver a abrir

"@ -ForegroundColor Red
    exit 1
}

Write-Host "`nConexion OK. Ahora PacMan deberia mostrar el boton Install activo." -ForegroundColor Green
Write-Host "Ejecuta: .\scripts\install-pacman.ps1" -ForegroundColor Green
