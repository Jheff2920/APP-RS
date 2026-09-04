# Boleta Print

Controlador Android de impresoras térmicas ESC/POS (58 / 80 / 110 mm).  
**No diseña boletas** — el POS las genera (PDF/imagen); esta app las imprime.

> Memoria técnica para agentes: [CONTEXTO.md](CONTEXTO.md)

**Versión:** 1.5.6+13 · Package ID: `com.example.hello_world_app`

---

## Estado actual (v1.5.6)

| Hecho | Pendiente |
|-------|-----------|
| Bluetooth Classic + WiFi TCP :9100 | v2: jobs HTTP/cola del POS |
| Compartir PDF/imagen → imprimir | USB/OTG |
| **PrintService** del sistema (diálogo Imprimir) | iOS |
| Overlay flotante (imprime sin saltar a la app) | |
| Tamaños de papel: 58 / 58 Max / 80 / **80 Max** / 110 | |
| Historial, márgenes L/R/inferior, página de prueba | |
| Márgenes de config aplican igual a PDF y a prueba | |
| Corte automático ESC/POS (como RawBT) | |
| Alta de impresora sin duplicados (ID estable + dedupe MAC) | |

---

## Qué hace

1. Vincular impresoras BT (emparejadas en Android) o WiFi.
2. Configurar **antes de guardar**: nombre, conexión, rollo 58/80, márgenes, corte, predeterminada.
3. **Compartir** un PDF/imagen a Boleta Print → imprimir.
4. Desde otra app: **Imprimir** → Boleta Print → recuadro flotante encima (no cambia de app).
5. Raster térmico `GS v 0` (mismo pipeline en Compartir y sistema).

---

## Ajustes de la impresora (mandan en todo)

Lo que guardas en **Editar impresora** se aplica a **PDF, imagen y página de prueba**:

| Ajuste | Efecto |
|--------|--------|
| Papel 58 / 80 mm | Ancho del raster (384 / 576 dots) |
| Margen izquierdo / derecho | Blanco dentro del área imprimible (no se recorta) |
| Margen inferior | Avance al terminar el ticket |
| Corte | Tras el margen inferior, envía el comando de cuchilla |

Flujo de cierre: **contenido → avance inferior (si > 0) → corte (si no es «Sin corte»)**.

> Tras cambiar márgenes o corte, pulsa **Guardar**. La impresión del sistema recarga siempre los valores desde disco (evita caché del engine headless).

---

## Activar impresión del sistema

1. Abre **Boleta Print** y vincula la impresora (elige 58 u 80 mm al guardar).
2. Concede **Mostrar sobre otras apps** (necesario en Android 10+ para el recuadro).
3. **Ajustes → Impresión** → activa **Boleta Print**.
4. PDF → **Imprimir** → elige la impresora → opcional: **Rollo 80 mm Max** para vista previa a ancho completo.

Sin el paso 3 solo verás RawBT u otros servicios.

---

## Cómo se imprime el PDF

1. Render → bitmap (`pdfx`) al **ancho útil** (rollo − márgenes L/R)
2. Recorte solo blanco superior/inferior (laterales los define la config)
3. Umbral B/N rápido
4. Colocar en sheet a ancho de rollo con padding izquierdo
5. `GS v 0` (franjas) + margen inferior (franjas blancas) + corte
6. Envío BT/TCP (bloque único si cabe; si no, chunks alineados a GS v 0)

**Por qué un PDF chico (~50 KB) tarda un poco:** el peso del archivo casi no importa; lo lento es rasterizar a bitmap y empaquetar `GS v 0`.

**Vista previa del sistema:** si el PDF del POS es angosto (~58) y eliges rollo 80, puede verse con margen; la impresión real usa el ancho configurado. Usa **Rollo 80 mm Max** para mejorar la preview.

Referencia de protocolo: `apk-ejemplo/` (RawBT) — no copiar código.

---

## Desarrollo rápido (sin Docker)

```powershell
# Instala en el dispositivo ADB conectado (o pasa -Serial)
.\scripts\run-phone.ps1 -InstallOnly
.\scripts\run-phone.ps1 -InstallOnly -Serial HA1KL54R

# Hot reload
.\scripts\run-phone.ps1
```

Dispositivos de prueba usados:

| Equipo | Serial ADB | Notas |
|--------|------------|--------|
| Xiaomi | `863d005830483132385114e3efc08c` | default del script |
| Lenovo YT-X705F | `HA1KL54R` | Android 10 · overlay obligatorio |

---

## Docker (APK portable)

```powershell
.\scripts\export-apk.ps1 -Build
```

> Debug local y Docker usan keystores distintos → no mezclar installs (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`).

---

## Estructura relevante

```
lib/
  main.dart / app.dart
  system_print_main.dart      # headless raster + fallback UI
  screens/                    # lista, formulario, share, historial
  services/
    print_service.dart
    escpos_pdf_print.dart / escpos_gs_v0.dart / escpos_feed.dart
    printer_store.dart        # prefs.reload + sync nativo + dedupe
    transports/               # BT (plugin) / WiFi TCP
android/.../printservice/
  BoletaPrintService.kt       # cola → overlay → raster → BT/WiFi nativo
  BoletaPrinterDiscoverySession.kt  # tamaños de papel del diálogo
  PrintSettingsActivity.kt
  SystemPrintOverlay.kt / EscPosTransport.kt
PrintEngineBridge.kt          # FlutterEngine headless
```

---

## Roadmap

1. **v1.1–v1.5** — hecho (Compartir, PrintService, overlay, Max paper, dedupe, márgenes PDF)
2. **v2** — jobs del POS por red/cola
3. USB/OTG, iOS

Detalle operativo: [CONTEXTO.md](CONTEXTO.md).
