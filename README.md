# Boleta Print

Controlador Android de impresoras térmicas ESC/POS (58 / 80 / 110 mm).  
**No diseña boletas** — el POS las genera (PDF/imagen); esta app las imprime.

**Repo:** https://github.com/Jheff2920/APP-RS  
**Versión:** 1.5.6+13 · Package ID: `com.example.hello_world_app`

> Memoria técnica para agentes: [CONTEXTO.md](CONTEXTO.md)

---

## Flujo de trabajo (no romper `main`)

`main` es la base estable. Las pruebas y experimentos van en ramas:

```powershell
# Partir siempre desde main actualizado
git checkout main
git pull

# Rama de pruebas
git checkout -b test/pruebas
# ... cambios de prueba ...
git add -A
git commit -m "Prueba: describe el cambio"
git push -u origin test/pruebas
```

Cuando algo salga bien: abre un Pull Request de `test/pruebas` → `main` en GitHub.  
No hagas push directo a `main` salvo hotfixes claros.

Rama lista para experimentar: **`test/pruebas`**.

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
| Corte automático ESC/POS | |
| Alta de impresora sin duplicados (ID estable + dedupe MAC) | |
| Repo limpio (sin dumps de ejemplo / secretos) | |

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

> Tras cambiar márgenes o corte, pulsa **Guardar**.

---

## Activar impresión del sistema

1. Abre **Boleta Print** y vincula la impresora (elige 58 u 80 mm al guardar).
2. Concede **Mostrar sobre otras apps** (necesario en Android 10+ para el recuadro).
3. **Ajustes → Impresión** → activa **Boleta Print**.
4. PDF → **Imprimir** → elige la impresora → opcional: **Rollo 80 mm Max** para vista previa a ancho completo.

---

## Cómo se imprime el PDF

1. Render → bitmap (`pdfx`) al ancho útil (rollo − márgenes L/R)
2. Recorte solo blanco superior/inferior
3. Umbral B/N rápido
4. Sheet a ancho de rollo con padding izquierdo
5. `GS v 0` + margen inferior + corte
6. Envío BT/TCP (bloque único si cabe; si no, chunks alineados)

Un PDF chico (~50 KB) puede tardar: lo lento es rasterizar, no el tamaño del archivo.

---

## Desarrollo rápido

```powershell
.\scripts\run-phone.ps1 -InstallOnly
.\scripts\run-phone.ps1 -InstallOnly -Serial HA1KL54R
.\scripts\run-phone.ps1
```

| Equipo | Serial ADB | Notas |
|--------|------------|--------|
| Xiaomi | `863d005830483132385114e3efc08c` | default del script |
| Lenovo YT-X705F | `HA1KL54R` | Android 10 · overlay obligatorio |

```powershell
.\scripts\export-apk.ps1 -Build
```

> Debug local y Docker usan keystores distintos → no mezclar installs.

---

## Qué no va en el repo

Ignorado a propósito (no subir):

- `apk-ejemplo/`, `apk2-ejemplo/`, `inst-apk/` — dumps de referencia / APKs locales
- `**/local.properties` — rutas del SDK en tu PC
- `*.env`, `key.properties`, `*.jks` / keystores
- `build/`, `.dart_tool/`

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
    printer_store.dart
    transports/               # BT / WiFi TCP
android/.../printservice/
  BoletaPrintService.kt
  BoletaPrinterDiscoverySession.kt
  SystemPrintOverlay.kt / EscPosTransport.kt
PrintEngineBridge.kt
```

---

## Roadmap

1. **v1.1–v1.5.6** — hecho (Compartir, PrintService, overlay, márgenes, repo limpio)
2. **v2** — jobs del POS por red/cola
3. USB/OTG, iOS

Detalle operativo: [CONTEXTO.md](CONTEXTO.md).
