# Contexto del proyecto — memoria de trabajo

> **Para Cursor / agente IA:** Lee este archivo al inicio de cada sesión nueva.

**Última actualización:** 2026-09-21 (v1.8.7, ticket SUNAT configurable)  
**Carpeta:** `C:\Users\RS-Soporte\Documents\app`  
**Versión:** `1.8.7+48`  
**Package ID:** `com.redpos.service`  
**iOS bundle:** `com.redpos.service`

---

## Objetivo

**RedPOS Service** — intermediario Android **e iOS** para impresoras térmicas ESC/POS.

- Imprime PDF/imagen del POS, o arma ticket desde **XML/ZIP UBL SUNAT** (boleta, factura, NC/ND, guía, retención).
- Android: Bluetooth Classic, TCP :9100 o USB host (impresora integrada IMIN/Falcon).
- iOS: TCP :9100 (camino fiable). Bluetooth solo BLE/MFi; no hay USB host ni PrintService.
- Entradas: **Compartir** / **Abrir archivo** (PDF/imagen/XML/ZIP). PrintService solo Android.

---

## Estado

- [x] Flutter local + Docker + `run-phone.ps1`
- [x] Impresoras BT/WiFi, márgenes, historial, página de prueba
- [x] PDF raster `GS v 0` (HL200B 58 mm y HQ300 80 mm)
- [x] PrintService + discovery: **58/80 mm** (Normal, Max, Google)
- [x] Overlay flotante (Android 10+): imprime sin traer la app al frente
- [x] Formulario: configurar rollo antes de guardar; sin duplicar al Probar/Guardar
- [x] Corte automatico ESC/POS configurable (tabla RawBT GS V / ESC i / ESC m)
- [x] Márgenes de config mandan en PDF e imagen (prefs.reload + pad L/R; inferior + corte)
- [x] Raster nativo `NativePdfEscPos` (preview → marco → geometría 384/576 → Matrix hi → umbral → GS v 0)
- [x] Ajustes: DPI 203/300 y nitidez x1/x2/x3 (misma medida; x2/x3 = más puntos en el recorte)
- [x] Gaveta opcional en un **segundo envío** tras espera (más larga en BT)
- [x] USB host bulk OUT (clase impresora o primer bulk); formulario + PrintService + Compartir
- [x] Falcon: gaveta por GPIO (`/sys/extcon-usb-gpio/cashbox_en`), no ESC/POS USB
- [x] XML SUNAT del ZIP CPE: 01/03/04/07/08/09/20/31/40 → ticket (ignora CDR)
- [x] Compartir/Abrir XML o ZIP CPE: copia a caché (Android 10 scoped storage)
- [x] iOS: WiFi :9100 + abrir PDF/XML/ZIP; USB/PrintService/GPIO ocultos
- [x] Android: emparejar Classic desde la app (`createBond` + PIN del sistema) y olvidar al desvincular (`removeBond`)
- [x] Formulario BT: emparejados vs Agregar dispositivo; scan pide ubicación en Android 10
- [x] Shell adaptativo (lista/detalle tablet) + scan BT sin relayout de toda la hoja
- [x] LAN: un socket nativo `:9100` (app + Chrome); idle 3 s suelta el puerto
- [x] PDF WiFi en Android: raster nativo (no `encode_page` en UI)
- [x] Play Billing + códigos RedPOS en `main`
- [x] Panel staff: generador `/` y control `/control.html` (precio global o por código)
- [x] Compartir imagen: recorte de voucher + umbral 168–200 (gris BCP = papel)
- [x] Ticket SUNAT configurable: formato (compacto/claro/detallado), logo y nota al pie
- [ ] Validar `flutter run` en Mac / iPhone
- [ ] v2 — jobs del POS (HTTP / cola)

---

## Flujos de impresión

### A) Compartir / Abrir archivo
`SEND`/`VIEW` (Android) o Abrir en / file picker (iOS) → `SharePrintScreen` → `PrintService.printSharedFile` → PDF/imagen raster **o** XML SUNAT (`SunatUblParser` + ESC/POS) → BT / USB / TCP.

En XML/ZIP, `SharePrintScreen` muestra la nota guardada para editarla en ese trabajo. El formato, el logo y la nota por defecto salen de `SunatPrintStore` (menú **Ticket SUNAT** o Ayuda). El ancho sigue siendo el de la impresora (58/80 mm).

### B) Sistema (Imprimir) — Android
1. `BoletaPrintService` recibe el PrintJob y copia el PDF.
2. Si hay overlay (`SYSTEM_ALERT_WINDOW`): recuadro flotante sobre la app actual.
3. `NativePdfEscPos` rasteriza en nativo (BT conecta en paralelo). Flutter solo si falla.
4. `EscPosTransport` envía por BT RFCOMM, USB bulk o TCP nativo. Gaveta: espera y segundo write (socket/USB abiertos).
5. `job.complete()` / `fail()`.

Sin overlay → notificación / fallback abriendo `MainActivity` (`SystemPrintUiHandler`).

### Activación usuario
1. Vincular impresora en la app (papel 58/80 + márgenes). En Falcon usa **USB**, no Bluetooth. En iPhone/iPad usa **WiFi :9100**.
2. En Android: permitir **Mostrar sobre otras apps** y activar **RedPOS Service** en Ajustes → Impresión.

---

## Decisiones

| Tema | Decisión |
|------|----------|
| PDF | Nativo `PdfRenderer` + `GS v 0` (Dart/`pdfx` solo fallback o Compartir) |
| PrintService | Raster nativo + envío nativo; Dart si el nativo falla |
| Preview 80 mm angosta | Chrome centra el ticket; la app recorta blanco y ajusta a 58/80 |
| Chrome 58 mm | 3000 mils (~76 mm) para que el margen de Chrome no encoja el ticket |
| Nitidez x2/x3 | No escala la página alta; Matrix solo sobre el recorte |
| Duplicados al guardar | ID estable en el formulario + dedupe por MAC/IP |
| Márgenes PDF | Misma config que prueba: L/R en sheet; inferior luego corte; gaveta después |
| Gaveta | Default off; BT/LAN: ESC p tras espera; Falcon USB: GPIO `cashbox_en` |
| USB Falcon | `vid:pid`; permiso USB se pierde al apagar. Pedirlo al imprimir (PrintService) y al abrir la app (`warmSavedUsbPermissions`), no solo al vincular. Gaveta GPIO. |
| Prefs headless | `SharedPreferences.reload()` en cada `loadAll()` |
| Build diario | `.\scripts\run-phone.ps1 -InstallOnly` |
| Referencia | `apk-ejemplo/` RawBT (protocolo, no pegar código) |
| XML SUNAT | ZIP CPE: Invoice/CreditNote/DebitNote/DespatchAdvice/Retention/Perception; ignora CDR `R-`; copia URI a caché |
| Ticket SUNAT | Formato compacto / claro (default) / detallado, QR y leyenda on/off. Logo PNG/JPG reducido en `SharedPreferences` (`sunat_print_logo_b64_v1`), centrado arriba con `GS v 0`. Nota al pie: default en ajustes; en Compartir se puede cambiar solo para ese trabajo (`sunatNote`). No toca PDF/imagen ni el pie de publicidad. |
| iOS | WiFi TCP 9100; BT solo BLE/MFi; USB/PrintService/GPIO Android-only; Abrir archivo + document types |
| Caps | `lib/platform_caps.dart` — no llamar canales USB en iOS |
| BT Android | Plugin `BluetoothBondPlugin`: scan Classic, `createBond`, `removeBond`, `listBonded`. Sin `neverForLocation`. Location on + permiso para discovery. iOS no puede unpair por API. |
| LAN 803L | Un cliente `:9100`. App + PrintService = mismo `heldNet`. Idle 3 s cierra el socket. Corte red: `ESC d` + `GS V 0x00`. |
| Compartir imagen | Recorta el recuadro claro (`EscPosImagePrep.cropVoucher`). Umbral promedio con piso 168 y tope 200 para no pintar pastilla/greca BCP. |
| UI | `BoletaPage` + lista/detalle ≥840 dp. Scan BT: lista altura fija + `ValueNotifier`, no `shrinkWrap`. |

---

## Hardware de prueba

| Ítem | Valor |
|------|--------|
| Xiaomi | ADB `863d005830483132385114e3efc08c` |
| Lenovo YT-X705F | ADB `HA1KL54R` · Android 10 |
| Lenovo TB-X306F | ADB `HPV4MC8C` |
| Impresora 58 | HL200B_0000 · `86:67:7A:04:C0:55` |
| Impresora 80 | HQ300_348C · `86:67:7A:02:34:8C` |
| IMIN Falcon 1 | 2 GB RAM · impresora integrada USB (como RawBT) |

---

## Pipeline PDF

1. Preview 1:1 + recorte (`findChromeTicketFrame` en Google/Max 58 y 80; si no, `findInkFrame`).
2. Geometría fija: `outW` = 384/576, `outH` proporcional al recorte (igual en x1/x2/x3).
3. Raster del recorte con Matrix a `outW*hi × outH*hi`. Umbral promedio; si hi>1, mayoría al rollo.
4. `GS v 0` franjas 48 → margen inferior → corte. Gaveta tras espera: `ESC p` (BT/LAN) o GPIO IMIN (USB Falcon).

---

## Archivos clave PrintService

- `android/.../printservice/BoletaPrintService.kt`
- `android/.../printservice/NativePdfEscPos.kt`
- `android/.../printservice/BoletaPrinterDiscoverySession.kt`
- `android/.../printservice/SystemPrintOverlay.kt`
- `android/.../printservice/EscPosTransport.kt`
- `android/.../NetworkLanPlugin.kt`
- `lib/services/network_lan_channel.dart`
- `admin-web/` (generador `/`, panel `/control.html`)
- `android/.../printservice/UsbEscPos.kt`
- `android/.../printservice/IminCashBox.kt`
- `android/.../UsbPrinterPlugin.kt`
- `android/.../printservice/PrintSettingsActivity.kt`
- `android/.../PrintEngineBridge.kt` (fallback)
- `lib/system_print_main.dart`
- `lib/services/sunat/` (`sunat_ubl_parser`, `sunat_escpos_print`, `sunat_print_settings`, `sunat_logo`)
- `lib/screens/sunat_print_settings_screen.dart`
- `lib/platform_caps.dart`
- `lib/services/bluetooth_bond_channel.dart`
- `android/.../BluetoothBondPlugin.kt`
- `ios/Runner/IncomingFile.swift` (Abrir con → tmp)

---

## Comandos

```powershell
.\scripts\run-phone.ps1 -InstallOnly
.\scripts\run-phone.ps1 -InstallOnly -Serial HA1KL54R
.\scripts\run-phone.ps1
```

iOS (Mac + Xcode):

```bash
flutter pub get
cd ios && pod install && cd ..
flutter run -d <iphone>
```

---

## Cómo retomar

> **v1.7.0:** Android + iOS. Emparejar/olvidar BT Classic en Android desde la app. iOS imprime por WiFi :9100 y abre XML/PDF/ZIP. USB/PrintService/GPIO siguen en Android.  
> **Prueba (fuera de main):** `test/redpos-activacion` — código RedPOS opcional, banner y pie de papel. Compilar iOS requiere un Mac.
