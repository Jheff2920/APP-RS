# Contexto del proyecto — memoria de trabajo

> **Para Cursor / agente IA:** Lee este archivo al inicio de cada sesión nueva.

**Última actualización:** 2026-09-08 (v1.6.7)  
**Carpeta:** `C:\Users\RS-Soporte\Documents\app`  
**Versión:** `1.6.7+24`  
**Package ID:** `com.example.hello_world_app`

---

## Objetivo

**Boleta Print** — intermediario Android para impresoras térmicas ESC/POS.

- No diseña boletas (las genera el POS).
- Bluetooth Classic o TCP :9100.
- Entradas: **Compartir** y **PrintService** (diálogo Imprimir del sistema).

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
- [x] Gaveta opcional (ESC p Pin 2/5) después del corte; default none
- [ ] v2 — jobs del POS (HTTP / cola)
- [ ] USB/OTG, iOS

---

## Flujos de impresión

### A) Compartir
`SEND`/`VIEW` → `SharePrintScreen` → `PrintService.printSharedFile` → BT plugin / TCP.

### B) Sistema (Imprimir) — camino principal
1. `BoletaPrintService` recibe el PrintJob y copia el PDF.
2. Si hay overlay (`SYSTEM_ALERT_WINDOW`): recuadro flotante sobre la app actual.
3. `NativePdfEscPos` rasteriza en nativo (BT conecta en paralelo). Flutter solo si falla.
4. `EscPosTransport` envía por BT RFCOMM o TCP nativo.
5. `job.complete()` / `fail()`.

Sin overlay → notificación / fallback abriendo `MainActivity` (`SystemPrintUiHandler`).

### Activación usuario
1. Vincular impresora en la app (papel 58/80 + márgenes).
2. Permitir **Mostrar sobre otras apps**.
3. Ajustes → Impresión → activar **Boleta Print**.

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
| Márgenes PDF | Misma config que prueba: L/R en sheet; inferior luego corte luego gaveta |
| Gaveta | Default off; ESC p pin 2 o 5 al terminar cada impresión |
| Prefs headless | `SharedPreferences.reload()` en cada `loadAll()` |
| Build diario | `.\scripts\run-phone.ps1 -InstallOnly` |
| Referencia | `apk-ejemplo/` RawBT (protocolo, no pegar código) |

---

## Hardware de prueba

| Ítem | Valor |
|------|--------|
| Xiaomi | ADB `863d005830483132385114e3efc08c` |
| Lenovo YT-X705F | ADB `HA1KL54R` · Android 10 |
| Impresora 58 | HL200B_0000 · `86:67:7A:04:C0:55` |
| Impresora 80 | HQ300_348C · `86:67:7A:02:34:8C` |

---

## Pipeline PDF

1. Preview 1:1 + recorte (`findChromeTicketFrame` en Google/Max 58 y 80; si no, `findInkFrame`).
2. Geometría fija: `outW` = 384/576, `outH` proporcional al recorte (igual en x1/x2/x3).
3. Raster del recorte con Matrix a `outW*hi × outH*hi`. Umbral promedio; si hi>1, mayoría al rollo.
4. `GS v 0` franjas 48 → margen inferior → corte → gaveta opcional (`ESC p`).

---

## Archivos clave PrintService

- `android/.../printservice/BoletaPrintService.kt`
- `android/.../printservice/NativePdfEscPos.kt`
- `android/.../printservice/BoletaPrinterDiscoverySession.kt`
- `android/.../printservice/SystemPrintOverlay.kt`
- `android/.../printservice/EscPosTransport.kt`
- `android/.../printservice/PrintSettingsActivity.kt`
- `android/.../PrintEngineBridge.kt` (fallback)
- `lib/system_print_main.dart`

---

## Comandos

```powershell
.\scripts\run-phone.ps1 -InstallOnly
.\scripts\run-phone.ps1 -InstallOnly -Serial HA1KL54R
.\scripts\run-phone.ps1
```

---

## Cómo retomar

> **v1.6.7:** Gaveta opcional (Pin 2/5) al imprimir. Geometría fija; x2/x3 no aplastan Google/Max.  
> Siguiente fase natural: **v2** (jobs del POS por red/cola).
