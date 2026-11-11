# Auditoría general del proyecto — 2026-11-02

Hecha por Claude Code (líder) + Codex (`codex exec --sandbox read-only`) como revisor,
más `flutter analyze` / `flutter test` reales. Rama: `feature/impresoras-logicas-independientes`.
Pendiente retomar: corregir bloqueantes, luego importantes, antes de integrar/publicar.

## Resultado de herramientas

- `flutter analyze`: 10 issues, todos info/warning (nada bloqueante). Incluye
  `use_build_context_synchronously` en printer_form_screen.dart y printer_list_screen.dart,
  un `unawaited_return_in_try_block` en redpos_play_billing.dart:156, y detalles de estilo.
- `flutter test`: **149/149 pasan.**
- Codex no pudo ejecutar flutter (lock de solo-lectura en su sandbox); análisis 100% manual
  sobre el código y el diff.

## Bloqueantes (corregir antes de publicar)

1. **Borrado arbitrario de archivos vía `system_print_path` sin autenticar.**
   `MainActivity` está exportada y acepta esa ruta sin validarla contra un registro interno;
   Flutter borra la ruta en un `finally` aunque la impresión falle. Una app externa que conozca
   una ruta privada de RedPOS podría forzar su borrado sin poder leerla.
   Refs: `android/app/src/main/kotlin/.../MainActivity.kt:76`, `lib/system_print_main.dart:298`.

2. **`R100301S` sigue vivo como contraseña administrativa de respaldo en el backend admin-web.**
   La eliminación documentada en CONTEXTO.md cubrió la app Flutter, pero no `admin-web`:
   si falta `REDPOS_STAFF_PASSWORD`, `staff.js:14` cae a esa clave (y el panel la hereda si no
   tiene una propia); `code.js` aún la reconoce como alias antes de que el endpoint la rechace
   (el endpoint sí rechaza con HTTP 400, verificado).
   Ref: `admin-web/lib/staff.js:14`.

## Importantes

3. Token de licencia local no firmado criptográficamente (JSON en Base64, solo exige nonce de
   8 caracteres) — con acceso de escritura a prefs se podría fabricar un pase.
   Refs: `lib/services/redpos/redpos_license.dart:105`, `redpos_code.dart:143`.
4. Build sin `REDPOS_API`/`REDPOS_HMAC` configurados cae a canje local con secreto de respaldo
   conocido en el cliente; el workflow de iOS compila así por defecto.
   Refs: `redpos_config.dart:5`, `redpos_license.dart:152`, `.github/workflows/ios-build.yml`.
5. El pase de Play se persiste sin fecha de expiración: si la revalidación falla o Billing no
   está disponible, queda desbloqueado indefinidamente.
   Refs: `redpos_license.dart:57`, `redpos_play_billing.dart:49`.
6. La cola de impresión puede quedar retenida globalmente por una operación nativa sin
   cancelación acotada (timeout de 45 s que vuelve a esperar sin límite real en el `finally`).
   Refs: `print_service.dart:284,372`, `EscPosTransport.kt:77`.
7. Recibos: `printSharedFile()` (flujo sin overlay) ignora `copies` — solo etiquetas lo
   multiplican. Pedir 3 copias de un recibo por ese camino imprime 1.
   Refs: `lib/system_print_main.dart:270`, `lib/services/print_service.dart:129`.
8. PDFs de recibos se truncan silenciosamente a 8 páginas (Dart y nativo), sin aviso.
   Refs: `lib/services/escpos_pdf_print.dart:60`, `NativePdfEscPos.kt:54`.
9. El wipe de privacidad no borra `shared_incoming` (Android) ni `incoming-*.png/jpg` (iOS):
   quedan copias de archivos compartidos tras "borrar todo".
   Refs: `privacy_data_wipe.dart:134`, `SharedIncomingFile.kt:20`, `IncomingFile.swift:55`.
10. ZIPs SUNAT sin límite de descompresión (riesgo zip-bomb / agotamiento de memoria).
    Ref: `lib/services/sunat/sunat_xml_source.dart:70`.

## Menores

11. Editar un tamaño de etiqueta puede cambiar el predeterminado implícito sin que el usuario
    lo elija (`_edit()` borra y re-agrega al final; si `defaultPaperProfileId` está vacío se usa
    el primero). Refs: `logical_printer_settings.dart:46`, `saved_printer.dart:75`.
12. Tickets propios: una pantalla de editor/preview ya abierta no revalida el pase si se pierde
    en caliente (riesgo bajo; no hay ruta de entrada directa sin pase).
    Refs: `custom_ticket_edit_screen.dart:106`, `custom_ticket_preview_screen.dart:45`.

## Cambios sin commitear (impresoras lógicas independientes) — evaluación

Compatibles hacia atrás (campos nuevos con defaults seguros), sin TODO/FIXME peligrosos,
no rompen flujos de recibos existentes. Falta cobertura de test para:
- Impresión de PDF con rango de páginas seleccionado + verificación de copias enviadas.
- Copias de recibos en el flujo sin overlay (relacionado con el bloqueante #7, que es previo
  al diff pero lo toca indirectamente).

## Conclusión

No listo para publicar por los bloqueantes #1 y #2. Recomendado: arreglar 1 y 2 primero
(tocan seguridad real: borrado arbitrario de archivos y contraseña admin de respaldo),
luego evaluar los importantes antes de integrar a `main`.

## Siguiente sesión

- [ ] Corregir bloqueante #1 (MainActivity / system_print_path)
- [ ] Corregir bloqueante #2 (R100301S en admin-web/staff.js y code.js)
- [ ] Decidir con el usuario cuáles importantes entran en este ciclo
- [ ] Añadir tests faltantes de rango de páginas/copias en etiquetas
- [ ] Re-review con Codex tras los fixes antes de cualquier commit+push
