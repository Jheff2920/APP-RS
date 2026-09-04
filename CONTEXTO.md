# Contexto del proyecto — memoria de trabajo

> **Para Cursor / agente IA:** Lee este archivo al inicio de cada sesión nueva.

**Última actualización:** 2026-09-04 (v1.5.6)  
**Carpeta:** `C:\Users\RS-Soporte\Documents\app`  
**Versión:** `1.5.6+13`  
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
- [x] PrintService + discovery + tamaños 58 / 58 Max / 80 / **80 Max** / 110
- [x] Overlay flotante (Android 10+): imprime sin traer la app al frente
- [x] Formulario: configurar rollo antes de guardar; sin duplicar al Probar/Guardar
- [x] Corte automatico ESC/POS configurable (tabla RawBT GS V / ESC i / ESC m)
- [x] Márgenes de config mandan en PDF e imagen (prefs.reload + pad L/R; inferior + corte)
- [ ] v2 — jobs del POS (HTTP / cola)
- [ ] USB/OTG, iOS

---

## Flujos de impresión

### A) Compartir
`SEND`/`VIEW` → `SharePrintScreen` → `PrintService.printSharedFile` → BT plugin / TCP.

### B) Sistema (Imprimir) — camino principal
1. `BoletaPrintService` recibe el PrintJob y copia el PDF.
2. Si hay overlay (`SYSTEM_ALERT_WINDOW`): recuadro flotante sobre la app actual.
3. `PrintEngineBridge` (FlutterEngine `systemPrintMain`) rasteriza → `.bin`.
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
| PDF | Raster `pdfx` + `GS v 0` (no Syncfusion texto) |
| PrintService | Headless Dart para raster; nativo para envío |
| Preview 80 mm angosta | PDF del POS ~58 mm; usar **Rollo 80 mm Max** en el diálogo |
| Duplicados al guardar | ID estable en el formulario + dedupe por MAC/IP |
| Márgenes PDF | Misma config que prueba: L/R en sheet; inferior luego corte |
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

Render al ancho útil → recorte arriba/abajo → umbral → sheet con márgenes L/R →
`GS v 0` franjas 512 → margen inferior (franjas blancas) → corte.
(Se revirtió el envío “un solo GS v 0 / ESC J” porque rompía impresión en HQ/HL.)

---

## Archivos clave PrintService

- `android/.../printservice/BoletaPrintService.kt`
- `android/.../printservice/BoletaPrinterDiscoverySession.kt`
- `android/.../printservice/SystemPrintOverlay.kt`
- `android/.../printservice/EscPosTransport.kt`
- `android/.../printservice/PrintSettingsActivity.kt`
- `android/.../PrintEngineBridge.kt`
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

> **v1.5.4:** Compartir + PrintService + márgenes de config en PDF.  
> Siguiente fase natural: **v2** (jobs del POS por red/cola).
