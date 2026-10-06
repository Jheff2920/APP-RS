# CONTEXTO — memoria para agentes IA

> **Lee este archivo primero** en cada sesión nueva (Cursor / Cloud / Claude / Codex).
> Es la fuente de verdad del estado actual del proyecto. Si README y este archivo discrepan, prioriza **CONTEXTO.md**.

**Última actualización:** 2026-10-06  
**Empresa:** **Red Soluciones** (una sola **d** — nunca «Redd Soluciones»)  
**Producto:** RedPOS Service  
**Carpeta Windows (preferida):** `C:\Users\RS-Soporte\Documents\app`  
**Repo:** https://github.com/Jheff2920/APP-RS · rama estable `main`  
**Versión app:** `1.8.8+51` (`pubspec.yaml`) — rediseño fusionado en `main`  
**Package / applicationId:** `com.redpos.service`  
**iOS bundle:** `com.redpos.service`

---

## Instrucciones para futuros AIs

1. **Lee CONTEXTO.md primero.** Luego `README.md` y, si toca Play/códigos/privacidad, `docs/DISTRIBUCION.md` y `docs/PRIVACIDAD.md`.
2. **No inventes funciones de IA generativa.** La app **no** usa generative AI ni ML sobre el contenido del usuario. Raster ESC/POS, recorte de vouchers y parseo XML SUNAT son algoritmos tradicionales. No agregues AdMob, Firebase Analytics, Crashlytics ni tracking.
3. **Ortografía de marca:** siempre **Red Soluciones** (una d). Producto visible: **RedPOS Service**.
4. **No subas secretos a git:** `android/upload-keystore.jks`, `android/key.properties`, `*.jks`, `*.env`, `local.properties`. El keystore de upload vive solo en el PC Windows RS-Soporte.
5. **Pase de pago existente:** usa `RedPosLicenseStore.isAdsFree()` (código empresa / suscripción Play / licencia de por vida). No inventes otro sistema de licencias. UI de bloqueo: `lib/widgets/redpos_paid_gate.dart`.
6. **Confirmación antes de cambios grandes:** el usuario prefiere español, confirmación antes de refactors amplios o borrados masivos.
7. **Checkout local Windows** cuando los agentes cloud no estén disponibles: máquina `DESKTOP-PSPCS8O` / path arriba. En PowerShell usa `;` entre comandos, **no** `&&`.
8. **Imprimir nunca se bloquea** por falta de pase; solo se bloquean extras de pago y Tickets propios.
9. Flujo git: rama de feature → PR → merge a `main`. No rompas `main` con WIP.

---

## Qué es la app

**RedPOS Service** — intermediario **Android e iOS** para impresoras térmicas ESC/POS (58 y 80 mm).

- Imprime PDF/imagen del POS, o arma ticket desde **XML/ZIP UBL SUNAT** (boleta, factura, NC/ND, guía, retención/percepción).
- **Tickets propios:** plantillas térmicas editables (feature de pago).
- Android: Bluetooth Classic, TCP `:9100`, USB host (IMIN/Falcon).
- iOS: TCP `:9100` (camino fiable). BT solo BLE/MFi; sin USB host ni PrintService.
- Entradas: Compartir / Abrir archivo (PDF/imagen/XML/ZIP). PrintService solo Android.

---

## Estado actual (v1.8.8+50 · oct 2026)

### Rama activa: `redesign/ui-simplificada` (4 commits adelante de `main`)

| Commit | Descripción |
|--------|-------------|
| `c82884d` | security: eliminar codigo maestro R100301S de la app |
| `2673529` | feat(ui): paleta de marca morada del logo RS, radios generosos |
| `805dd07` | feat(ui): redesign pantalla principal y tema de marca |
| `cc6e0c8` | chore(release): bump version to 1.8.8+50 |

### En `main`

| Área | Qué hay |
|------|---------|
| Ticket SUNAT | Formatos compacto / claro / detallado; logo; nota al pie; QR (tamaños `size6` / `size7` para mejor escaneo) |
| Tickets propios | Plantillas 58/80 mm, preview, impresión, IGV opcional («Incluir IGV»), **sin campo título** en UI/print/preview |
| Acentos | Code table **CP1252** (`setGlobalCodeTable('CP1252')`) + `latin1Safe` en SUNAT y tickets propios (ñ, tildes) |
| Paid gate | `RedPosLicenseStore.isAdsFree()` — código RedPOS / Play sub / lifetime |
| SUNAT de pago | Logo, nota al pie, contenido QR (toggle), monto en letras (`showLegend`) — gratis: elegir formato |
| Tickets propios | Feature **completa** de pago (UI + enforce en `PrintService.printCustomTicket`) |
| Privacidad | Pantalla **Datos y privacidad**, wipe local, política en admin-web + HTTPS |
| Branding | Red Soluciones (corregido; una d) |
| Play / códigos | Billing + canje API; ads de primera parte (banner + pie papel), **sin AdMob** |
| Red TCP | Fix half-open socket (commit `a5ba131`): fresh connection por trabajo, retry x2, `EscPosTransport` + `NetworkTransport` |

### Privacidad y terceros (Play compliance)

- Política: https://redpos-codigos-prueba.vercel.app/privacidad.html  
- Copia markdown: `docs/PRIVACIDAD.md` · HTML: `admin-web/public/privacidad.html`  
- In-app: `lib/screens/privacy_data_screen.dart`, `lib/legal/legal_copy.dart`, wipe: `lib/services/privacy_data_wipe.dart`
- **No** generative AI; **no** AdMob / Firebase Analytics / Crashlytics.
- Nota: Play Billing 8.x trae transitivamente `datatransport` (`transport-backend-cct`) y envía telemetría propia a `firebaselogging.googleapis.com`; no es un SDK Firebase de la app. Los textos de privacidad lo declaran; no lo borres de ellos.
- Terceros: Play Billing (`in_app_purchase`), Google Sign-In (solo al suscribirse), API códigos RedPOS (Vercel), plugins de impresión local, SharedPreferences.

### Firma y builds

- Keystore upload: `android/upload-keystore.jks` + `android/key.properties` **solo en PC Windows RS-Soporte**, gitignored. Plantilla: `android/key.properties.example`.
- AAB Play / APK: salen a `inst-apk\` como `RedPOS-Service-*-play.aab` / APKs (carpeta **no** va a git).
- Compilar con define de API:

```powershell
flutter build apk --release --dart-define=REDPOS_API=https://redpos-codigos-prueba.vercel.app
flutter build appbundle --release --dart-define=REDPOS_API=https://redpos-codigos-prueba.vercel.app
```

- Script diario: `.\scripts\run-phone.ps1 -InstallOnly`

### Hardware de prueba

| Ítem | Valor |
|------|--------|
| **Telpo M1K** (principal actual) | Serial ADB `A51M001K03800032` |
| Xiaomi | ADB `863d005830483132385114e3efc08c` |
| Lenovo YT-X705F | ADB `HA1KL54R` · Android 10 |
| Lenovo TB-X306F | ADB `HPV4MC8C` |
| Impresora 58 | HL200B_0000 · `86:67:7A:04:C0:55` |
| Impresora 80 | HQ300_348C · `86:67:7A:02:34:8C` |
| IMIN Falcon 1 | USB integrado; gaveta por GPIO `cashbox_en` |

### Preferencias del usuario (Jeferson / RS-Soporte)

- Idioma: **español**
- Confirmar antes de cambios grandes
- Preferir checkout local Windows cuando cloud no esté disponible
- PowerShell: `;` no `&&`

---

## Paid gate (detalle)

Misma condición que quita publicidad:

```dart
await RedPosLicenseStore.instance.isAdsFree();
```

Orígenes del pase: token de código RedPOS (empresa / lifetime) **o** entitlement Play (`redpos_ads_free_monthly`).

| Feature | Sin pase | Con pase |
|---------|----------|----------|
| Imprimir PDF/imagen/XML SUNAT | Sí (siempre) | Sí |
| Formato ticket SUNAT (compacto/claro/detallado) | Sí | Sí |
| Logo empresa SUNAT | No (omitido al imprimir) | Sí |
| Nota al pie SUNAT | No | Sí |
| Toggle QR / monto en letras | No (defaults seguros vía `withoutPaidExtras()`) | Sí |
| Tickets propios (lista/editar/preview/print) | Bloqueado (UI + throw en print) | Sí |
| Ads banner + pie de papel | Sí | No |

Enforce en print: `lib/services/print_service.dart` (`_buildSunatTicket`, `printCustomTicket`).  
UI: `lib/screens/sunat_print_settings_screen.dart`, `lib/screens/custom_tickets_list_screen.dart`, `lib/widgets/redpos_paid_gate.dart`.

---

## Arquitectura — carpetas clave

```
lib/
  brand.dart                 # AppBrand.name = RedPOS Service
  platform_caps.dart         # Caps Android vs iOS
  legal/legal_copy.dart      # Textos legales in-app
  screens/
    sunat_print_settings_screen.dart
    custom_tickets_list_screen.dart
    custom_ticket_edit_screen.dart
    custom_ticket_preview_screen.dart
    privacy_data_screen.dart
    legal_screen.dart
    share_print_screen.dart
  services/
    sunat/                   # UBL parse + ESC/POS ticket SUNAT
      sunat_ubl_parser.dart
      sunat_escpos_print.dart   # CP1252 + QR size6/size7
      sunat_print_settings.dart # format, footer, QR, legend; withoutPaidExtras()
      sunat_logo.dart
      sunat_ticket.dart
      sunat_xml_source.dart
    custom_ticket/           # Tickets propios
      custom_ticket.dart        # includeIgv, sin título en UI
      custom_ticket_escpos.dart # CP1252
      custom_ticket_store.dart
    redpos/
      redpos_license.dart       # isAdsFree(), códigos, Play
      redpos_code.dart
      redpos_config.dart
    privacy_data_wipe.dart
    print_service.dart
    transports/ ...
  widgets/
    redpos_paid_gate.dart
    redpos_ad_banner.dart
    printer_card.dart          # Tarjeta impresora (rediseño) — icono tipo + "Probar" + badge
android/.../printservice/    # BoletaPrintService, NativePdfEscPos, EscPosTransport, USB, overlay
admin-web/                   # Generador códigos + privacidad/terminos (Vercel)
docs/
  DISTRIBUCION.md
  PRIVACIDAD.md
  PRINT_PERFORMANCE.md
inst-apk/                    # Artefactos locales (gitignored)
```

---

## Flujos de impresión (resumen)

### A) Compartir / Abrir
`SharePrintScreen` → `PrintService.printSharedFile` → PDF/imagen raster **o** XML SUNAT (`SunatUblParser` + `SunatEscPosPrint`) → BT / USB / TCP.

### B) Tickets propios (pago)
Lista/editar/preview → `PrintService.printCustomTicket` → `CustomTicketEscPos.build`.

### C) Sistema Imprimir (Android)
`BoletaPrintService` → overlay opcional → `NativePdfEscPos` → `EscPosTransport`.

Orden típico en papel: **contenido → margen inferior → (ads pie si sin pase) → corte → espera → gaveta**.

---

## Decisiones vigentes (no reinventar)

| Tema | Decisión |
|------|----------|
| PDF | Nativo `PdfRenderer` + `GS v 0`; Dart/`pdfx` fallback |
| Code page texto | **CP1252** para acentos/ñ (SUNAT + tickets propios) |
| Paid extras SUNAT | Logo, footer, QR toggle, monto en letras; formato gratis |
| Tickets propios | Feature de pago completa; IGV 18% opcional; sin campo título |
| Licencia | Reusar `isAdsFree()`; no nuevo licensing |
| Ads | Primera parte RedPOS; no AdMob |
| IA | No hay generative AI en la app |
| Empresa | Red Soluciones (una d) |
| LAN :9100 | Un socket nativo compartido; idle 3 s suelta el puerto; fresh-connect por job (commit `a5ba131`) |
| Falcon gaveta | GPIO `cashbox_en`, no ESC/POS USB |
| Prefs headless | `SharedPreferences.reload()` en `loadAll()` |
| Secretos | Keystore solo en PC; nunca commit |

---

## Comandos útiles

```powershell
# Sync
git checkout main; git pull

# Dev install
.\scripts\run-phone.ps1 -InstallOnly
.\scripts\run-phone.ps1 -InstallOnly -Serial A51M001K03800032

# Release (con API de códigos)
flutter build apk --release --dart-define=REDPOS_API=https://redpos-codigos-prueba.vercel.app
flutter build appbundle --release --dart-define=REDPOS_API=https://redpos-codigos-prueba.vercel.app

# Timing
adb logcat | Select-String BoletaPrintTiming
```

Staff códigos: https://redpos-codigos-prueba.vercel.app/ · control: `/control.html`

---

## Rediseño UI en curso (`redesign/ui-simplificada`)

### Cambios ya aplicados

**Concepto:** papel térmico. El único elemento "atrevido" es el ticket del inicio
(`_ReceiptHero`): sale de la franja morada bajo el AppBar, esquinas superiores
redondeadas (radio 20, igual que `_DetailSheet`) y borde inferior dentado
(`TornPaperClipper(topRadius: 20)`) y muestra la impresora principal + "Imprimir archivo" / "Probar".
Todo lo demás es sobrio: grupos blancos con separadores internos.

**`lib/theme.dart`** — tokens en `AppColors` (brand `#2B0A53`, fondo `#F5F3F9`,
papel blanco, tinta `#1C1530`, ok `#1B7F5A`, warn `#9A5B00`). Radios: inputs/botones 12,
cards 16, sheets 24, dialogs 24. Tema de SegmentedButton, Switch, PopupMenu, DropdownMenu.
**No** pongas `border: const OutlineInputBorder()` en campos: anula el radio del tema.

**`lib/widgets/ui_kit.dart`** — componentes compartidos (usar siempre):
`IconTile`, `SectionLabel`, `SectionGroup` (filas con divisores), `SectionBody`, `NavRow`,
`SwitchRow`, `OptionRow` (radio), `EmptyMessage`, `InfoNote` (neutral/ok/warn/error),
`ButtonSpinner`, `PageList` (ListView centrado máx. 640), `BottomActions` (barra inferior),
`PrinterPicker` (reemplaza dropdowns de impresora), `TornPaperClipper`, `shortTime`, `dayHeading`,
`printerTypeIcon/Color`.

**Distribución por pantalla:**
- Inicio: ticket hero (impresora principal + botón ⋯ de opciones + "Imprimir archivo"/"Probar";
  en ancho <340 dp "Probar" y "Vincular otra" pasan a enlaces) → lista "Impresoras (n)" **solo si hay
  más de una** → fila "Herramientas" → banner gratis al final. Sin FAB. Menú ⋮ (tooltip `Ayuda y legal`)
  solo ayuda/legal. Tablet ≥840: franja morada baja (`_ReceiptHero.compactBand` 22 dp, papel en
  `compactPaperTop` 16 dp; en vertical/teléfono 52/46) cruza todo el ancho;
  inicio 440 dp sin centrado vertical + panel de detalle como hoja redondeada (`_DetailSheet`)
  que empieza en `_ReceiptHero.paperTop`, igual que el ticket. Cabecera del panel blanca
  (Theme override) y `NavigatorPopHandler` para que Atrás no cierre la app.
- Pantallas altas (tablet vertical): `_BalancedFill` (RenderObject en `printer_list_screen.dart`)
  centra el bloque del inicio alargando la franja morada y, si cabe, muestra `_BrandHeader`
  (monograma `assets/brand/rs_mark.png`, copia de `ic_launcher_foreground.png`, + frase).
- `PageList` y `BottomActions` comparten bordes (máx. 640 dp menos 16 dp de margen).
- `PrinterCard`: nombre hasta 2 líneas, badge "Principal" en la 2.ª línea; botón "Probar" solo ícono si ancho <400.
- Botones de confirmar acciones destructivas (desvincular, borrar, eliminar) en rojo (`colorScheme.error`).
- Hoja de opciones de impresora: encabezado + `NavRow`s; "Desvincular" aparte en rojo.
- Imprimir archivo: tarjeta del archivo (tipo detectado) → `PrinterPicker` → bloque SUNAT; botón fijo "Imprimir en X".
- Historial: agrupado por día (Hoy/Ayer/fecha) con hora corta y origen legible.
- Formulario impresora: Conexión (segmentado + lista de dispositivos seleccionables) → Nombre →
  Papel → Corte y gaveta → Ajuste fino (márgenes/nitidez plegados + principal) → Publicidad (código opcional).
  Barra inferior: [Probar] [Guardar]. Se quitó "Continuar con publicidad": código vacío = guarda con publicidad.
- Ticket SUNAT: formatos como `OptionRow` con explicación; extras de pago o lista bloqueada + banner.
- Tickets propios: tarjetas con logo/ícono, botón imprimir directo; editor en bloques; vista previa como papel 58/80 mm.

**Tests:** `sunat_print_settings_test` usa `_tallView` (800×1600) porque la pantalla es más larga;
el acceso a SUNAT en la prueba del inicio se toca directo en Herramientas. 83/83 pasan.

**Seguridad — código maestro eliminado:**
- `lib/services/redpos/redpos_config.dart`: eliminados `allowTestCodes` y `testCode = 'R100301S'`
- `lib/services/redpos/redpos_code.dart`: eliminados `testAlias`, `isTestAlias()`, bypass en `verify()`
- `lib/services/redpos/redpos_license.dart`: eliminado nonce `TESTALIAS` y 3 guards de `testAlias`
- `test/redpos_code_test.dart`: nuevo test confirma que `R100301S` es **rechazado**
- Únicos desbloqueos válidos: código HMAC empresa, suscripción Play, lifetime key

### Estado (2026-10-06)

Todas las pantallas rediseñadas (inicio, formulario, compartir, historial, SUNAT, tickets propios
lista/editor/vista previa, ayuda, suscripción, privacidad, legal, banners de pago). Revisado con
capturas en Lenovo YT-X705F (horizontal y vertical) y aprobado por el usuario → **fusionado a `main`**.

**Play Console (versionCode 50 rechazado por política de fotos/videos):** el manifiesto declaraba
`READ_MEDIA_IMAGES` sin usarlo (logos y archivos van por `FilePicker` = selector del sistema).
Se quitó y se añadió `tools:node="remove"` para `READ_MEDIA_IMAGES` y `READ_MEDIA_VIDEO`.
Ningún plugin los declara. **No volver a agregar permisos de fotos/videos.**
Versión subida a `1.8.8+51` para el nuevo AAB.

**Capturas de pago (Yape/BCP) compartidas:** `SharedIncomingFile.kt` añade la extensión según el MIME
cuando el nombre no la trae (antes se guardaban como `sunat_*.xml` y fallaban). En Dart,
`sniffFileKind()` (`print_service.dart`) detecta PNG/JPG/WebP/GIF/PDF/ZIP por cabecera antes del
chequeo SUNAT. Pendiente: probar compartir desde Yape y BCP con la build +51.

Gradle desde la sesión del agente falla por WinNAT (`Unable to establish loopback connection`);
compilar desde la terminal del usuario.

### Próximos pasos (en orden)

1. Compilar AAB `1.8.8+51` con `--dart-define=REDPOS_API=...` y copiarlo a `inst-apk\`
2. Subirlo a Play Console y en "Problemas detectados" usar "Actualizar paquetes afectados"
3. Confirmar en el merged manifest que no aparece `READ_MEDIA_*`
4. Revisar en teléfono real (Telpo M1K) el inicio en ancho angosto

---

## Pendiente / no hacer aún

- [ ] Validar `flutter run` en Mac / iPhone de forma rutinaria
- [ ] v2 — jobs del POS (HTTP / cola)
- [ ] No añadir generative AI, AdMob, Firebase analytics
- [ ] No commitear keystore / key.properties
- [ ] KGP warning: `file_picker` y `pdfx` usan Kotlin Gradle Plugin antiguo — no urgente

---

## Cómo retomar (changelog corto)

- **1.8.8+50 (rama redesign/ui-simplificada):** Rediseño UI morado marca, PrinterCard nuevo, eliminado código maestro R100301S, fix TCP half-open socket.
- **1.8.8+49 → +50 (main):** Bump versionCode, fix TCP half-open socket.
- **1.8.8+49:** Tickets propios (IGV opcional, sin título), paid gate SUNAT+custom, CP1252, QR más grande, privacidad Play, branding Red Soluciones.
- **1.8.7:** Ticket SUNAT configurable (formato/logo/nota), builds previos de imagen voucher / LAN idle.
- Detalle histórico largo: ver `README.md` y commits en `main`.
