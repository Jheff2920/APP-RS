# CONTEXTO — memoria para agentes IA

> **Lee este archivo primero** en cada sesión nueva (Cursor / Cloud / Claude / Codex).
> Es la fuente de verdad del estado actual del proyecto. Si README y este archivo discrepan, prioriza **CONTEXTO.md**.

**Última actualización:** 2026-10-01 (estado de features al 2026-09-28 / inicios de octubre 2026)  
**Empresa:** **Red Soluciones** (una sola **d** — nunca «Redd Soluciones»)  
**Producto:** RedPOS Service  
**Carpeta Windows (preferida):** `C:\Users\RS-Soporte\Documents\app`  
**Repo:** https://github.com/Jheff2920/APP-RS · rama estable `main`  
**Versión app:** `1.8.8+49` (`pubspec.yaml`)  
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

## Estado actual (v1.8.8+49 · sept–oct 2026)

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

### Privacidad y terceros (Play compliance)

- Política: https://redpos-codigos-prueba.vercel.app/privacidad.html  
- Copia markdown: `docs/PRIVACIDAD.md` · HTML: `admin-web/public/privacidad.html`  
- In-app: `lib/screens/privacy_data_screen.dart`, `lib/legal/legal_copy.dart`, wipe: `lib/services/privacy_data_wipe.dart`
- **No** generative AI; **no** AdMob / Firebase Analytics / Crashlytics.
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
| LAN :9100 | Un socket nativo compartido; idle 3 s suelta el puerto |
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

## Pendiente / no hacer aún

- [ ] Validar `flutter run` en Mac / iPhone de forma rutinaria
- [ ] v2 — jobs del POS (HTTP / cola)
- [ ] No añadir generative AI, AdMob, Firebase analytics
- [ ] No commitear keystore / key.properties

---

## Cómo retomar (changelog corto)

- **1.8.8+49:** Tickets propios (IGV opcional, sin título), paid gate SUNAT+custom, CP1252, QR más grande, privacidad Play, branding Red Soluciones.
- **1.8.7:** Ticket SUNAT configurable (formato/logo/nota), builds previos de imagen voucher / LAN idle.
- Detalle histórico largo: ver `README.md` y commits en `main`.
