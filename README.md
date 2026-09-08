# Boleta Print

Controlador Android de impresoras térmicas ESC/POS (58 y 80 mm).  
**No diseña boletas** — el POS las genera (PDF/imagen); esta app las imprime.

**Repo:** https://github.com/Jheff2920/APP-RS  
**Versión:** 1.6.7+24 · Package ID: `com.example.hello_world_app`  
**Rama estable:** `main` · **Rama de pruebas:** `test/pruebas`

> Memoria técnica: [CONTEXTO.md](CONTEXTO.md) · Rendimiento: [docs/PRINT_PERFORMANCE.md](docs/PRINT_PERFORMANCE.md)

---

## Dónde quedamos (2026-09-08)

- Raster nativo (`NativePdfEscPos`): recorte de tinta + umbral promedio + `GS v 0`.
- **Nitidez x1/x2/x3** imprime al **mismo tamaño** (384/576). x2/x3 solo rasterizan el recorte a más puntos (no aplastan Google/Max).
- Chrome 58 mm: ancho 3000 mils (~76 mm) para que el ticket no se encoja a la mitad. 80 mm sigue en 3150.
- Google/Max (58 y 80): recorte del ticket Chrome; geometría fija al rollo.
- Gaveta de dinero opcional (Pin 2 / Pin 5) al terminar de imprimir; default «Sin gaveta».

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

## Estado actual (v1.6.7)

| Hecho | Pendiente |
|-------|-----------|
| Bluetooth Classic + WiFi TCP :9100 | v2: jobs HTTP/cola del POS |
| Compartir PDF/imagen → imprimir | USB/OTG |
| PrintService + overlay flotante | iOS |
| Papel 58 / 80 mm + DPI 203/300 + nitidez x1/x2/x3 | |
| Márgenes L/R/inf + corte + gaveta opcional | |
| Dedupe impresoras (ID estable + MAC) | |
| Pipeline más rápido + métricas `BoletaPrintTiming` | |
| Tests GS v0 / EscPosChunker + benchmark local | |
| Repo limpio en GitHub | |

---

## Qué hace

1. Vincular impresoras BT (emparejadas en Android) o WiFi.
2. Configurar antes de guardar: rollo, DPI, nitidez, márgenes, corte, gaveta, predeterminada.
3. Compartir PDF/imagen → imprimir.
4. Diálogo **Imprimir** del sistema → overlay sin saltar de app.
5. Raster `GS v 0` (Compartir y PrintService).

---

## Ajustes de la impresora

| Ajuste | Efecto |
|--------|--------|
| Papel 58 / 80 mm | Ancho del rollo |
| DPI 203 / 300 | Puntos del cabezal (203: 384/576; 300: 576/832) |
| Nitidez x1 / x2 / x3 | Misma medida que x1; x2/x3 más nítido y un poco más lento |
| Márgenes L/R | Blanco en el área imprimible |
| Margen inferior | Avance al terminar |
| Corte | Después del margen inferior |
| Gaveta | Opcional: pulso Pin 2 o Pin 5 al terminar (default off) |

**contenido → avance inferior → corte → gaveta**. Guardar tras cambiar ajustes.

---

## Impresión desde Chrome / sistema

En **Imprimir** elige el ancho del papel. El PDF se imprime **tal cual** (sin estirar):

| Tamaño | Ancho | Vista previa |
|--------|--------|----------------|
| Rollo 58 mm | 384 puntos | Página corta (ancho Chrome 76 mm) |
| Rollo 58 mm Max | 384 puntos | Página larga (PDF completo) |
| Rollo 58 mm Google | 384 puntos | Chrome: evita el encogimiento a la mitad |
| Rollo 80 mm | 576 puntos | Página corta |
| Rollo 80 mm Max | 576 puntos | Página larga (PDF completo) |
| Rollo 80 mm Google | 576 puntos | Chrome: página extra ancha, ticket 80 mm |

Desde **Google/Chrome** usa **Rollo 80 mm Google** (o 58). La app **recorta el blanco y ajusta el ticket al rollo**. x1, x2 y x3 salen del mismo largo y ancho; x2/x3 solo afinan el dibujo.

Usa **Max** si en Chrome no se ve toda la boleta y no quieres la medida Google. Max no cambia el ancho: solo alarga la preview.

---

## Pipeline PDF (resumen)

Preview + recorte → geometría 384/576 → raster del recorte (x2/x3 a más puntos) → umbral GS v0 → feed + corte + gaveta → BT/TCP.

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

1. **v1.6.7** — estable en `main` (raster nativo, nitidez, Chrome 58/80, gaveta opcional)
2. **v2** — jobs del POS por red/cola
3. USB/OTG, iOS
