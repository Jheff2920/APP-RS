# Boleta Print

Controlador Android de impresoras térmicas ESC/POS (58 y 80 mm).  
**No diseña boletas** — el POS las genera (PDF/imagen); esta app las imprime.

**Repo:** https://github.com/Jheff2920/APP-RS  
**Versión:** 1.6.1+18 · Package ID: `com.example.hello_world_app`  
**Rama estable:** `main` · **Rama de pruebas:** `test/pruebas`

> Memoria técnica: [CONTEXTO.md](CONTEXTO.md) · Rendimiento: [docs/PRINT_PERFORMANCE.md](docs/PRINT_PERFORMANCE.md)

---

## Dónde quedamos (2026-09-07)

- Raster nativo (`NativePdfEscPos`) alineado a RawBT: recorte de tinta + umbral promedio.
- Calidad verificada contra RawBT (mismo look a x1).
- Ajustes: **DPI 203/300** y **nitidez x1/x2/x3** (x2/x3 tarda más y puede verse más nítido).
- Chrome/Google: recorta el ticket y llena el rollo 58/80.

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

## Estado actual (v1.6.1)

| Hecho | Pendiente |
|-------|-----------|
| Bluetooth Classic + WiFi TCP :9100 | v2: jobs HTTP/cola del POS |
| Compartir PDF/imagen → imprimir | USB/OTG |
| PrintService + overlay flotante | iOS |
| Papel 58 / 80 mm + DPI 203/300 + nitidez x1/x2/x3 | |
| Márgenes L/R/inf + corte (config manda en PDF y prueba) | |
| Dedupe impresoras (ID estable + MAC) | |
| Pipeline más rápido + métricas `BoletaPrintTiming` | |
| Tests GS v0 / EscPosChunker + benchmark local | |
| Repo limpio en GitHub | |

---

## Qué hace

1. Vincular impresoras BT (emparejadas en Android) o WiFi.
2. Configurar antes de guardar: rollo, DPI, nitidez, márgenes, corte, predeterminada.
3. Compartir PDF/imagen → imprimir.
4. Diálogo **Imprimir** del sistema → overlay sin saltar de app.
5. Raster `GS v 0` (Compartir y PrintService).

---

## Ajustes de la impresora

| Ajuste | Efecto |
|--------|--------|
| Papel 58 / 80 mm | Ancho del rollo |
| DPI 203 / 300 | Puntos del cabezal (203: 384/576; 300: 576/832) |
| Nitidez x1 / x2 / x3 | x1 rápido (RawBT); x2/x3 más nítido y más lento |
| Márgenes L/R | Blanco en el área imprimible |
| Margen inferior | Avance al terminar |
| Corte | Después del margen inferior |

**contenido → avance inferior → corte**. Guardar tras cambiar ajustes.

---

## Impresión desde Chrome / sistema

En **Imprimir** elige el ancho del papel. El PDF se imprime **tal cual** (sin estirar):

| Tamaño | Ancho | Vista previa |
|--------|--------|----------------|
| Rollo 58 mm | 384 puntos | Página corta |
| Rollo 58 mm Max | 384 puntos | Página larga (PDF completo) |
| Rollo 58 mm Google | 384 puntos | Chrome: página extra ancha, ticket 58 mm |
| Rollo 80 mm | 576 puntos | Página corta |
| Rollo 80 mm Max | 576 puntos | Página larga (PDF completo) |
| Rollo 80 mm Google | 576 puntos | Chrome: página extra ancha, ticket 80 mm |

Desde **Google/Chrome** usa **Rollo 80 mm Google** (o 58). Chrome deja el ticket de LIMAFAC a ~58 mm y centrado. Esa medida **recorta el blanco y ajusta el ticket al rollo** (escala uniforme, el texto no se deforma).

Usa **Max** si en Chrome no se ve toda la boleta y no quieres la medida Google. Max no cambia el ancho: solo alarga la preview.

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
