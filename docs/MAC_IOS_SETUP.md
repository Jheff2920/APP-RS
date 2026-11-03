# Configurar la Mac para probar RedPOS Service en iOS

> Lee primero [CONTEXTO.md](../CONTEXTO.md). Este documento es solo la guía
> operativa para dejar el proyecto corriendo en una Mac nueva.

**Estado:** el proyecto nunca se compiló en iOS todavía (ver "Pendiente" en
README.md y CONTEXTO.md: "Validar `flutter run` en Mac / iPhone"). No hay
secretos ni archivos `.env`/`GoogleService-Info.plist` faltantes — el único
bloqueo real es la firma con una cuenta de Apple, resuelta abajo sin pagar.

## 1. Herramientas

```bash
xcode-select --install        # Command Line Tools
sudo gem install cocoapods
```

Flutter 3.47.2 (misma versión usada en Windows para este proyecto; channel
stable):

```bash
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
flutter doctor
```

`flutter doctor` debe confirmar Xcode y CocoaPods en verde. Android toolchain
es opcional en la Mac (solo si también vas a compilar Android ahí).

## 2. Clonar y preparar

```bash
git clone https://github.com/Jheff2920/APP-RS.git
cd APP-RS
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

Abre siempre el `.xcworkspace`, nunca el `.xcodeproj` a secas (sin los Pods
no compila). `ios/Pods/`, `.symlinks/` y `xcuserdata/` son generados por
`pod install`/Xcode y ya están en `.gitignore` — no se deben commitear.

## 3. Probar en el Simulador (sin cuenta de Apple)

```bash
open -a Simulator
flutter run
```

Sirve para ver la UI (pantallas, diálogos, el switch de "Oscuridad
personalizada" nuevo, etc.), pero **no imprime de verdad**: no hay
Bluetooth/red real de impresora en el Simulador.

## 4. Probar en un iPhone físico con Apple ID gratis (sin pagar los 99 USD/año)

No hace falta cuenta de pago para correr en tu propio iPhone durante
pruebas de desarrollo.

En Xcode:

1. **Xcode → Settings → Accounts → `+`** → inicia sesión con un Apple ID
   normal.
2. Clic en **Runner** (panel izquierdo) → pestaña **Signing & Capabilities**.
3. Marca **Automatically manage signing**.
4. En **Team** elige tu cuenta ("Tu Nombre (Personal Team)").
5. Si Xcode marca error de "Bundle Identifier is not available" (porque
   `com.redpos.service` ya está registrado por la cuenta real de la
   empresa): cambia el bundle ID **solo localmente**, nunca lo commitees,
   por ejemplo a `com.redpos.service.dev` en ese mismo panel de Xcode —
   es solo para firmar en tu máquina de pruebas.

Conecta el iPhone por cable y:

```bash
flutter devices
flutter run
```

Primera vez en el iPhone: **Ajustes → General → VPN y gestión de
dispositivos** → confiar en el certificado de desarrollador.

**Limitaciones del Apple ID gratis** (no developer account):
- La app instalada expira a los 7 días; se reinstala con `flutter run` de
  nuevo. Normal, no es un bug.
- No se pueden probar compras/suscripciones reales de App Store en sandbox
  sin cuenta de pago. El código de activación por API (`RedPosLicenseStore`)
  sí funciona igual, porque no depende de Apple.

## 5. Qué probar específicamente en iOS

Ver CONTEXTO.md, sección "Qué es la app" y "Estado actual": en iOS la vía
de impresión confiable es **WiFi TCP :9100**; Bluetooth solo si la
impresora es **BLE/MFi** (Bluetooth Classic clásico, como en Android, no
aparece — limitación de Apple, no de la app); no hay USB host ni
PrintService (eso es solo Android).

Checklist de esta ronda:
- [ ] Compartir/Abrir PDF, imagen y XML/ZIP SUNAT.
- [ ] Impresión por WiFi TCP :9100 con una impresora real.
- [ ] Bluetooth si la impresora es BLE/MFi.
- [ ] Feature de impresoras lógicas independientes (recibos/etiquetas) y
  los fixes de la sesión 2026-11-03 (oscuridad, protocolo ESC/POS por
  defecto, PDF con extensión equivocada) — es lógica Dart pura, no debería
  comportarse distinto que en Android, pero conviene confirmarlo.

## 6. Si algo no compila

- `pod install` falla con versión de CocoaPods vieja → `sudo gem update
  cocoapods`.
- Error de Kotlin Gradle Plugin al compilar Android desde la Mac: es un
  warning conocido y preexistente (`file_picker`, `pdfx` aplican KGP), no
  bloquea el build.
- `flutter doctor` marcando Xcode desactualizado: `ios/Podfile` fija
  `platform :ios, '13.0'`; Xcode recientes piden a veces subir el
  deployment target — si pasa, avisar antes de tocarlo (afecta qué iPhones
  viejos siguen soportados).
