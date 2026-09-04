# Boleta Print

Controlador Android de impresoras térmicas ESC/POS (58 / 80 / 110 mm).  
**No diseña boletas** — el POS las genera (PDF/imagen); esta app las imprime.

**Repo:** https://github.com/Jheff2920/APP-RS  
**Versión:** 1.5.6+13 · Package ID: `com.example.hello_world_app`  
**Rama estable:** `main` · **Rama de pruebas:** `test/pruebas`

> Memoria técnica: [CONTEXTO.md](CONTEXTO.md) · Rendimiento: [docs/PRINT_PERFORMANCE.md](docs/PRINT_PERFORMANCE.md)

---

## Dónde quedamos (2026-09-04)

- Impresión PDF/prueba **estable** (márgenes de config, corte, PrintService + overlay).
- Mejoras de rendimiento fusionadas a `main` (GS v0 más rápido, chunking BT, timing).
- Repo limpio en GitHub (sin dumps de ejemplo ni secretos).

**Mañana:** seguir en `test/pruebas` para experimentos; si algo sale bien → merge a `main`.

---

## Flujo de trabajo (no romper `main`)

```powershell
git checkout main
git pull
git checkout test/pruebas   # o: git checkout -b test/nueva-prueba
# ... cambios ...
git add -A
git commit -m "Prueba: describe el cambio"
git push -u origin HEAD
```

Cuando valide en impresora real, merge a `main` (PR o merge local + push).

---

## Estado actual (v1.5.6)

| Hecho | Pendiente |
|-------|-----------|
| Bluetooth Classic + WiFi TCP :9100 | v2: jobs HTTP/cola del POS |
| Compartir PDF/imagen → imprimir | USB/OTG |
| PrintService + overlay flotante | iOS |
| Papel 58 / 58 Max / 80 / 80 Max / 110 | |
| Márgenes L/R/inf + corte (config manda en PDF y prueba) | |
| Dedupe impresoras (ID estable + MAC) | |
| Pipeline más rápido + métricas `BoletaPrintTiming` | |
| Tests GS v0 / EscPosChunker + benchmark local | |
| Repo limpio en GitHub | |

---

## Qué hace

1. Vincular impresoras BT (emparejadas en Android) o WiFi.
2. Configurar antes de guardar: rollo, márgenes, corte, predeterminada.
3. Compartir PDF/imagen → imprimir.
4. Diálogo **Imprimir** del sistema → overlay sin saltar de app.
5. Raster `GS v 0` (Compartir y PrintService).

---

## Ajustes de la impresora

| Ajuste | Efecto |
|--------|--------|
| Papel 58 / 80 mm | Ancho del raster (384 / 576 dots) |
| Márgenes L/R | Blanco en el área imprimible |
| Margen inferior | Avance al terminar |
| Corte | Después del margen inferior |

**contenido → avance inferior → corte**. Guardar tras cambiar ajustes.

---

## Activar impresión del sistema

1. Vincular impresora en la app.
2. Permiso **Mostrar sobre otras apps**.
3. Ajustes → Impresión → activar **Boleta Print**.
4. PDF → Imprimir → elegir impresora (opcional: Rollo 80 mm Max).

---

## Pipeline PDF (resumen)

Render al ancho útil → umbral/empaquetado GS v0 → márgenes → feed + corte → envío BT/TCP (chunks seguros).

Detalle y cómo medir tiempos: [docs/PRINT_PERFORMANCE.md](docs/PRINT_PERFORMANCE.md).

```powershell
adb logcat | Select-String BoletaPrintTiming
C:\flutter\bin\cache\dart-sdk\bin\dart.exe run tool\benchmark_escpos.dart
```

---

## Desarrollo rápido

```powershell
.\scripts\run-phone.ps1 -InstallOnly
.\scripts\run-phone.ps1 -InstallOnly -Serial HA1KL54R
.\scripts\run-phone.ps1
.\scripts\export-apk.ps1 -Build
```

| Equipo | Serial ADB | Notas |
|--------|------------|--------|
| Xiaomi | `863d005830483132385114e3efc08c` | default del script |
| Lenovo YT-X705F | `HA1KL54R` | Android 10 · overlay obligatorio |

> Debug local y Docker usan keystores distintos → no mezclar installs.

---

## Qué no va en el repo

- `apk-ejemplo/`, `apk2-ejemplo/`, `inst-apk/`
- `**/local.properties`, `*.env`, `key.properties`, `*.jks`
- `build/`, `.dart_tool/`

---

## Estructura relevante

```
lib/services/     escpos_pdf_print, escpos_gs_v0, print_timing, transports/
android/.../printservice/   BoletaPrintService, EscPosTransport, EscPosChunker
docs/PRINT_PERFORMANCE.md
tool/benchmark_escpos.dart
```

---

## Roadmap

1. **v1.5.6** — estable en `main` (impresión + rendimiento + repo limpio)
2. **v2** — jobs del POS por red/cola
3. USB/OTG, iOS
