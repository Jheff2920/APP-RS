# Boleta Print

Controlador Android de impresoras térmicas ESC/POS (58 y 80 mm).  
Imprime PDF/imagen del POS **o** convierte el **XML/ZIP UBL de SUNAT** (boleta, factura, NC/ND, guía de remisión, retención/percepción) a ticket 58/80 mm.

**Repo:** https://github.com/Jheff2920/APP-RS  
**Versión:** 1.6.18+35 · Package ID: `com.example.hello_world_app`  
**Rama estable:** `main` · **Rama de pruebas:** `test/pruebas`

> Memoria técnica: [CONTEXTO.md](CONTEXTO.md) · Rendimiento: [docs/PRINT_PERFORMANCE.md](docs/PRINT_PERFORMANCE.md)

---

## Dónde quedamos (2026-09-09)

- Raster nativo (`NativePdfEscPos`): recorte de tinta + umbral promedio + `GS v 0`.
- **Nitidez x1/x2/x3** imprime al **mismo tamaño** (384/576). x2/x3 solo rasterizan el recorte a más puntos (no aplastan Google/Max).
- Chrome 58 mm: ancho 3000 mils (~76 mm) para que el ticket no se encoja a la mitad. 80 mm sigue en 3150.
- Todos los rollos 58/80 (Normal, Max, Google): misma página alta + recorte Chrome, como **80 mm Max**.
- Gaveta **después** del ticket (espera extra en Bluetooth; en LAN ~0.3 s).
- USB host (impresora integrada IMIN/Falcon): lista, permiso `vid:pid` y envío bulk ESC/POS.
- En Falcon la gaveta **no va por USB**: se pulsa el GPIO del equipo (`cashbox_en`), como el plugin IMIN. En BT/LAN se sigue usando `ESC p`.
- **XML/ZIP SUNAT:** Compartir o Abrir el CPE. En Android 10+ se copia a caché (Descargas no es legible). El CDR (`R-...`) no se imprime.

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

## Estado actual (v1.6.18)

| Hecho | Pendiente |
|-------|-----------|
| Bluetooth Classic + WiFi TCP :9100 + USB host | v2: jobs HTTP/cola del POS |
| Compartir PDF/imagen **o XML/ZIP SUNAT** → imprimir | iOS |
| PrintService + overlay flotante | |
| Papel 58 / 80 mm + DPI 203/300 + nitidez x1/x2/x3 | |
| Márgenes L/R/inf + corte + gaveta **después** del papel | |
| Dedupe impresoras (ID estable + MAC / USB vid:pid) | |
| Pipeline más rápido + métricas `BoletaPrintTiming` | |
| Tests GS v0 / EscPosChunker + benchmark local | |
| Repo limpio en GitHub | |

---

## Qué hace

1. Vincular impresoras BT (emparejadas en Android), WiFi o **USB** (Falcon/IMIN integrada).
2. Configurar antes de guardar: rollo, DPI, nitidez, márgenes, corte, gaveta, predeterminada.
3. Compartir PDF/imagen → imprimir tal cual (raster).
4. Compartir / Abrir **XML o ZIP SUNAT** (boleta, factura, NC, guía, etc.) → ticket 58 u 80 mm + QR.
5. Diálogo **Imprimir** del sistema (PDF) → overlay sin saltar de app.

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
| Gaveta | Opcional (default off). Pin 2 o Pin 5: en BT/LAN envía `ESC p` **después** del papel; en Falcon/USB pulsa el GPIO del terminal |

**contenido → avance inferior → corte → espera → gaveta**. Guardar tras cambiar ajustes.

En **Bluetooth** la espera es ~2.5–8 s (el cajón no debe abrirse mientras aún sale el ticket). En USB Falcon ~0.8 s y luego GPIO; en LAN ~0.3 s + `ESC p`.

---

## Impresión desde Chrome / sistema

En **Imprimir** elige el ancho del papel. El PDF se imprime **tal cual** (sin estirar):

| Tamaño | Ancho | Vista previa |
|--------|--------|----------------|
| Rollo 58 mm / Max / Google | 384 puntos | Página alta + recorte al rollo (igual que 80 Max) |
| Rollo 80 mm / Max / Google | 576 puntos | Página alta + recorte al rollo |

Desde **Google/Chrome** usa **Rollo 80 mm Google** (o 58). La app **recorta el blanco y ajusta el ticket al rollo**. x1, x2 y x3 salen del mismo largo y ancho; x2/x3 solo afinan el dibujo.

Usa **Max** si en Chrome no se ve toda la boleta y no quieres la medida Google. Max no cambia el ancho: solo alarga la preview.

---

## XML / ZIP SUNAT

Desde **Archivos** o la consulta CPE: **Compartir** o **Abrir con → Boleta Print** el `.xml` o el `.zip`.

| Código | Comprobante | Raíz UBL |
|--------|-------------|----------|
| 01 | Factura | `Invoice` |
| 03 | Boleta | `Invoice` |
| 04 | Liquidación de compra | `Invoice` |
| 07 | Nota de crédito | `CreditNote` |
| 08 | Nota de débito | `DebitNote` |
| 09 | Guía de remisión remitente | `DespatchAdvice` |
| 31 | Guía de remisión transportista | `DespatchAdvice` |
| 20 | Retención | `Retention` |
| 40 | Percepción | `Perception` |

- El ZIP de SUNAT trae el CPE y el CDR (`R-...xml` / `ApplicationResponse`). Solo se imprime el CPE.
- El ancho es el de la impresora (58 o 80 mm). QR SUNAT: `RUC|tipo|serie|numero|IGV|total|fecha|doc|nro`.
- NC/ND muestran el documento afectado (`Afecta: F002-...`). La guía muestra motivo, placa, partida y llegada (sin IGV/total).
- En Android 10+ hay que **Compartir** o **Abrir con**; la app copia el archivo a su caché (no lee Descargas directo).
- El diálogo Imprimir del sistema sigue siendo para PDF.

---

## Pipeline PDF (resumen)

Preview + recorte → geometría 384/576 → raster del recorte (x2/x3 a más puntos) → umbral GS v0 → feed + corte → BT/USB/TCP → espera → gaveta (`ESC p` o GPIO IMIN).

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
| IMIN Falcon 1 | (ADB del equipo) | 2 GB RAM · impresora integrada por **USB** |

> Debug local y Docker usan keystores distintos → no mezclar installs.

---

## Qué no va en el repo

- `apk-ejemplo/`, `apk2-ejemplo/`, `apk-imin/`, `inst-apk/`
- `**/local.properties`, `*.env`, `key.properties`, `*.jks`
- `build/`, `.dart_tool/`

---

## Estructura relevante

```
lib/services/     escpos_pdf_print, sunat/, print_timing, transports/, usb_printer_channel
android/.../printservice/   BoletaPrintService, EscPosTransport, UsbEscPos, IminCashBox
android/.../SharedIncomingFile.kt   copia URI Compartir/Abrir a caché
docs/PRINT_PERFORMANCE.md
tool/benchmark_escpos.dart
```

---

## Roadmap

1. **v1.6.18** — CPE del ZIP SUNAT: boleta, factura, NC/ND, guía, retención/percepción; copia a caché en Android 10
2. **v1.6.17** — Compartir XML/ZIP como IMPRIMIRSUNAT (caché + latin1)
3. **v1.6.16** — Nota de crédito 07 y débito 08
4. **v1.6.15** — Gaveta en todos los tamaños 58/80; XML SUNAT + USB Falcon
5. **v2** — jobs del POS por red/cola
6. iOS
