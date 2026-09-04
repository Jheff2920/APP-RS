# Medición de rendimiento de impresión

La app registra métricas locales sin contenido del ticket, rutas, MAC ni IP.
Los eventos Dart y Android usan el nombre/tag `BoletaPrintTiming`.

## Capturar una ejecución

```powershell
adb logcat -c
adb logcat | Select-String BoletaPrintTiming
```

Ejecutar siempre con el mismo PDF y anotar por separado:

1. PrintService en frío: cerrar la app y detener el proceso antes de imprimir.
2. PrintService caliente: repetir sin detener el proceso.
3. Compartir desde Android.
4. Bluetooth y TCP, si ambos están disponibles.
5. Papel 58 mm y 80 mm.

Cada escenario necesita al menos cinco repeticiones. Usar la mediana, no el
mejor tiempo.

Para comparar solamente umbral y empaquetado raster sin una impresora:

```powershell
C:\flutter\bin\cache\dart-sdk\bin\dart.exe run tool\benchmark_escpos.dart
```

Referencia local del 2026-09-04 para 576 × 1800 px:

- Pipeline anterior: mediana 154.83 ms.
- Umbral + empaquetado fusionados: mediana 24.71 ms.
- Mejora: 84.0 %, con salida ESC/POS idéntica (129 632 bytes).

## Fases registradas

- `copy_pdf` / `fallback_copy_pdf`: copia desde el spooler Android.
- `engine_ready`: disponibilidad del engine headless; `cold=true` identifica
  el primer arranque.
- `load_preferences`: lectura de impresora y márgenes.
- `open_pdf`, `render_page`, `encode_page`: preparación raster.
- `bluetooth_connect` / `network_connect`: apertura del transporte.
- `bluetooth_write` / `network_write`: envío y protección previa al cierre.
- `system_total` / `finish`: duración total conocida por la app.

La app no recibe confirmación física de la impresora. Para medir el tiempo
hasta el primer movimiento y hasta el corte se necesita cronómetro o video.

## Criterio de comparación

- No aceptar una optimización si aumenta fallos, corta bandas, degrada QR/texto
  pequeño o altera margen inferior/corte.
- Comparar `prepare`, `engine_ready` y `write` por separado.
- Validar en HL200B 58 mm y HQ300 80 mm antes de reducir `flush` o esperas de
  desconexión.
