# Adaptive Material 3 shell for printer linking on Android and iOS

Written against: `0447846210551446dfbe0b9c9f22273659068827`

This file is the only source of truth for the executor. Do not use chat history. Do not change ESC/POS, PrintService, or `android/app/src/main/res/layout/print_overlay.xml`.

## Evidence chain

- Surface: Flutter `BoletaPrintApp` in `lib/app.dart`. Home is `PrinterListScreen`. From there: `PrinterFormScreen` (push), `SharePrintScreen` (share intent push), `PrintHistoryScreen` (push or named route `/history`). Dialogs: overlay permission, unlink, print status (`runWithPrintStatusDialog`), clear history.
- Problem: One Material 3 teal theme, but every screen is a phone-width column. Form primary actions sit at the end of a long `ListView`. `SharePrintScreen` pins `Imprimir` with `Spacer` (overflow on short viewports). Only the printer-actions bottom sheet uses `SafeArea`. Empty copy says «Bluetooth o WiFi» while the form already offers USB. Unlink always cites Bluetooth pairing on Android. List sheet says «Probar impresion» next to dialog title «Impresión del sistema». iOS launcher name is `Hello World App` while Android label and the AppBar are `Boleta Print`.
- Design evidence: `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), useMaterial3: true)` in `lib/app.dart`. Material 3 window widths: compact &lt; 600, medium 600–839, expanded ≥ 840. `PrinterLinkType.label` in `lib/models/saved_printer.dart` (`Bluetooth`, `WiFi / Red`, `USB`). `CONTEXTO.md` activation step: Falcon uses USB, not Bluetooth. Accent exemplar: `Impresión del sistema` in `lib/screens/printer_list_screen.dart` (overlay dialog) and `android/app/src/main/res/layout/print_settings.xml`. Android visible name: `android:label="Boleta Print"` in `android/app/src/main/AndroidManifest.xml`.
- Owner: `lib/app.dart` theme; screens under `lib/screens/`; connection labels on `PrinterLinkType`.
- Scope and affected surfaces: `lib/app.dart`, new `lib/theme.dart`, new layout widget under `lib/widgets/`, `lib/screens/printer_list_screen.dart`, `lib/screens/printer_form_screen.dart`, `lib/screens/share_print_screen.dart`, `lib/screens/print_history_screen.dart`, `lib/widgets/print_status_dialog.dart` (user-facing `Impresion enviada` only), `ios/Runner/Info.plist` (`CFBundleDisplayName` only), `test/widget_test.dart`.
- Uncertainty: iOS print, Bluetooth, USB, and share pipelines are unfinished product work (`CONTEXTO.md`). This plan covers layout, insets, platform-gated chrome, and launcher name only.

## Design decision

Rebuild the printer-management chrome as one adaptive Material 3 shell owned by the existing teal `ColorScheme`. Compact keeps today’s stack. Medium centers content at 600 dp. Expanded may use list-detail; if split state is unsafe, use the medium centered stack on all widths ≥ 600 instead of inventing a second navigation model.

Keep primary actions on screen: form `Guardar` + `Probar impresión`, share `Imprimir`, each in a bottom bar with `SafeArea`.

Align connection copy with `PrinterLinkType.label`. Gate USB and the system-overlay permission dialog to Android. Set iOS `CFBundleDisplayName` to `Boleta Print`.

Do not add a palette, font, radius scale, or `darkTheme`.

## Reuse

- Theme: `ColorScheme.fromSeed(seedColor: Colors.teal)` and `useMaterial3: true`. Move that exact `ThemeData` to `lib/theme.dart` as `boletaPrintTheme`. Optional only: `visualDensity: VisualDensity.standard` and `appBarTheme` derived from the same `colorScheme`. No second seed. No `darkTheme`.
- Buttons: `FilledButton` / `FilledButton.icon` primary (Vincular, Guardar, Imprimir, Permitir, Desvincular confirm). `OutlinedButton.icon` secondary (Probar impresión). `TextButton` dismiss (Después, Cancelar). `FloatingActionButton.extended` «Vincular» on compact/medium list when the pane is the list.
- Selection: `SegmentedButton` for exclusive enums (link type, paper, DPI, raster). `DropdownMenu` for cut and cash drawer. Do not restyle those sections.
- Lists: `Card` + `ListTile` + `CircleAvatar` for printers; `Card` + `ListTile` three-line for history. Bottom sheet: `showModalBottomSheet` + `showDragHandle: true` + `SafeArea` (already in `_showPrinterActions`).
- Connection labels: `PrinterLinkType.label` only. Values: `Bluetooth`, `WiFi / Red`, `USB`. Do not keep `BT` or `WiFi` as parallel segment text.
- Page padding already on lists: `EdgeInsets.all(16)` and compact list `EdgeInsets.fromLTRB(16, 16, 16, 88)` to clear the FAB.
- Empty state structure: `_EmptyState` in `lib/screens/printer_list_screen.dart` — `Icons.print_disabled` size 64 with `colorScheme.outline`, `textTheme.titleLarge` title «Sin impresoras vinculadas», `FilledButton.icon` «Vincular impresora».
- Progress: keep `PrintStatusDialog` / `runWithPrintStatusDialog`. Do not restyle. Change only `PrintPhase.done` message `Impresion enviada` → `Impresión enviada`. History status colors `Colors.green` / `Colors.red` / `Colors.orange` stay unless mapped to existing `colorScheme.primary` / `colorScheme.error` / `colorScheme.tertiary` with no new hex.
- Android MainActivity already has `android:windowSoftInputMode="adjustResize"`. Rely on that; do not change the manifest.

New composition (layout only, not a visual system): `BoletaPage` in `lib/widgets/boleta_page.dart`. Needed because no shared widget currently applies `SafeArea`, max width 600, and a sticky bottom bar. Consumers: form, share, history bodies, and the list empty state. Compact printer list with cards stays full width and does not use the 600 cap.

Breakpoints (local `double`, not a token file): `MediaQuery.sizeOf(context).width`

- compact: width &lt; 600
- medium: 600 ≤ width &lt; 840
- expanded: width ≥ 840

Max content width on medium/expanded when not in a working list-detail pane: `600`.

## Changes

1. `lib/theme.dart` (create) and `lib/app.dart`
   - Change: export a top-level `ThemeData boletaPrintTheme` equal to today’s theme (`ColorScheme.fromSeed(seedColor: Colors.teal)`, `useMaterial3: true`). In `BoletaPrintApp.build`, set `theme: boletaPrintTheme`. Do not add `darkTheme`. Do not change `navigatorKey`, share handling, `title: 'Boleta Print'`, `home: PrinterListScreen`, or `routes['/history']`.
   - Preserve: `SystemPrintUiHandler` bind, share stream, `PrinterStore` / `PrintService` constructor args.
   - Verify: `test/widget_test.dart` still finds text `Boleta Print`. No other `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)` remains in `lib/`.

2. `lib/widgets/boleta_page.dart` (create)
   - Change: a `StatelessWidget` with `child`, optional `bottomBar`, optional `maxContentWidth` default `600`, optional `constrainWhenWidthAtLeast` default `600`. Body: `SafeArea` (top false when the parent `Scaffold` already has an `AppBar`). If width ≥ `constrainWhenWidthAtLeast`, center the child with `ConstrainedBox` max width `maxContentWidth` and `width: double.infinity` so fields stretch inside the cap. If `bottomBar != null`, put it below the expanded child in a `Column` (child `Expanded` + `SingleChildScrollView` or pass-through), with the bar in `Material` + top `Divider(height: 1)` + horizontal padding 16 + vertical padding 8, itself inside `SafeArea` for bottom/left/right.
   - Preserve: no colors, fonts, or radii beyond `Theme.of(context)`.
   - Verify: on width 360 the child is full width (minus SafeArea); on width 700 the child is at most 600 dp centered; bottom bar remains visible while the child scrolls.

3. `lib/screens/printer_list_screen.dart`
   - Change:
     - `_maybeAskOverlay`: return immediately unless `Platform.isAndroid` (import `dart:io`). Then keep the existing dialog (`Impresión del sistema`, Después / Permitir).
     - `_unlink` content: always `¿Quitar "${printer.name}" de Boleta Print?`. Append a second paragraph only when `printer.type == PrinterLinkType.bluetooth`: on Android `(No borra el emparejado Bluetooth del sistema Android.)`; on iOS `(No borra el emparejado Bluetooth del sistema.)`.
     - Bottom sheet action title: `Probar impresión` (replace `Probar impresion`).
     - `_EmptyState`: take `bool showUsb`. Body copy must use `PrinterLinkType` labels. Android (`showUsb == true`): `Vincula una impresora térmica (Bluetooth, WiFi / Red o USB). El historial de trabajos se ve en el icono de reloj o en las opciones de cada impresora.\n\nTambién puedes compartir un PDF hacia esta app desde otras apps.` iOS: same but `(Bluetooth o WiFi / Red)` with no USB. Keep title `Sin impresoras vinculadas` and button `Vincular impresora`. Wrap empty state in `BoletaPage` (no bottom bar). Keep icon and `titleLarge`.
     - Compact and medium: keep `FloatingActionButton.extended` label `Vincular`, list padding `fromLTRB(16, 16, 16, 88)`, `Card`+`ListTile` as today.
     - Expanded (width ≥ 840): prefer a `Row` with the printer list on the left (~0.4) and a detail pane on the right (~0.6). Opening add/edit form or history sets the detail child instead of `Navigator.push`. Hide the FAB while the detail is the add form so Vincular is not duplicated; show an AppBar `IconButton` (`Icons.add` / tooltip `Vincular`) on the list pane when the FAB is hidden. If wiring two panes would duplicate `PrinterStore` state or break `_reload` after save, do not implement split: use `BoletaPage` max width 600 for empty state and keep stack `Navigator.push` for form/history (stop-condition fallback).
   - Preserve: `_reload`, `_testPrint` + `runWithPrintStatusDialog`, history from AppBar and from the sheet, `setDefault`, delete, card subtitle `Predeterminada · ${p.type.label} · ${p.paper.label}`.
   - Verify: empty state on Android mentions `USB` and `WiFi / Red`. Unlink of a WiFi printer has no Bluetooth parenthetical. Overlay dialog never runs on iOS. Sheet says `Probar impresión`.

4. `lib/screens/printer_form_screen.dart`
   - Change: wrap the `Form` in `Scaffold` body as `BoletaPage` with sticky bottom bar: `FilledButton.icon` Guardar (existing `_save()` / saving spinner) then `SizedBox(height: 8)` then `OutlinedButton.icon` `Probar impresión` (existing `_test` / testing spinner). Both `stretch` (`SizedBox(width: double.infinity)` or `Column` crossAxis stretch). Move the two buttons out of the `ListView`. Keep the 80 mm preview helper `bodySmall` as the last item in the scrollable fields, not in the bar. `ListView` padding stays `EdgeInsets.all(16)` inside the page child.
   - Connection section title: `Conexión` (replace `Conexion`).
   - `SegmentedButton<PrinterLinkType>`: build segments from `PrinterLinkType.bluetooth`, `PrinterLinkType.network`, and `PrinterLinkType.usb` only if `Platform.isAndroid`. Each `ButtonSegment.label` is `Text(type.label)` (so `Bluetooth`, `WiFi / Red`, `USB`). Keep existing icons (`Icons.bluetooth`, `Icons.wifi`, `Icons.usb`). If `_type == PrinterLinkType.usb` on iOS (should not happen for new printers), coerce to `PrinterLinkType.bluetooth` in `initState` when `!Platform.isAndroid`.
   - SnackBar after test: `Página de prueba enviada` (replace `Pagina de prueba enviada`).
   - Preserve: `_formKey` validation, `_id` stable, `_persistSettings` on DPI and raster, `_loadPaired` / `_loadUsb` / `_pickUsb`, paper `PaperWidthSelector`, margin sliders, cut/cash `DropdownMenu`, default switch, USB helper copy for Falcon.
   - Verify: on a short viewport Guardar is visible without scrolling to the end. Android shows three segments including `USB`. iOS shows two segments and no USB fields.

5. `lib/screens/share_print_screen.dart`
   - Change: replace the `Column` + `Spacer` + `Imprimir` structure. Use `BoletaPage` with scrollable child (file `Card` + title `Impresora vinculada` + empty text or `DropdownButtonFormField`) and sticky `FilledButton.icon` `Imprimir` (same enablement: not `_printing` and `_selected != null`, same spinner). Keep padding 16 via `BoletaPage` / child.
   - Preserve: `_load` default printer, XML vs PDF icon/subtitle, `runWithPrintStatusDialog` + pop on success, empty copy `No hay impresoras vinculadas. Abre Boleta Print, agrega una impresora y vuelve a compartir el archivo.`
   - Verify: `Imprimir` stays on screen at height ~400 with the file card visible above. Keyboard resize does not hide the button behind the home indicator (`SafeArea` on the bar).

6. `lib/screens/print_history_screen.dart`
   - Change: wrap body in `BoletaPage` (no bottom bar). AppBar title when unfiltered: `Historial de impresión`. Empty: `Sin trabajos de impresión todavía.` Clear dialog: `¿Borrar todo el historial de impresión?` List padding remains `EdgeInsets.all(16)`, separator 8, `Card`+`ListTile` `isThreeLine: true`.
   - Preserve: `widget.printer` filtered title `Historial · ${name}`, delete AppBar action, clear scoped to printer, status icons and current colors.
   - Verify: titles contain `impresión` with accent. Three-line tiles still show name, status, source, timestamp.

7. `lib/widgets/print_status_dialog.dart`
   - Change: `PrintPhase.done` `message` getter from `Impresion enviada` to `Impresión enviada`. Do not change layout, spinner, or colors.
   - Preserve: `runWithPrintStatusDialog` timing and `PopScope`.
   - Verify: done phase copy matches the accent exemplar.

8. `ios/Runner/Info.plist`
   - Change: `CFBundleDisplayName` from `Hello World App` to `Boleta Print`.
   - Preserve: `CFBundleName` (`hello_world_app`), all `UISupportedInterfaceOrientations` and `UISupportedInterfaceOrientations~ipad` entries (portrait + landscape, iPad upside-down).
   - Verify: the display-name string is `Boleta Print`. It is not `Hello World App`.

9. `test/widget_test.dart`
   - Change: keep `Shows empty printers state` expecting `Sin impresoras` and `Boleta Print`. After the existing pumps, also expect the empty body is not the old Bluetooth-only sentence: `find.textContaining('Bluetooth o WiFi')` finds nothing. Expect `find.textContaining('WiFi / Red')` (Android test default includes USB path copy). Optionally `find.textContaining('USB')`.
   - Preserve: `SharedPreferences.setMockInitialValues({})`, `BoletaPrintApp(store:, printService:)`, `pump` then `pump(Duration(milliseconds: 500))`.
   - Verify: `flutter test test/widget_test.dart` passes.

## Scope

- Inherit: `PrinterListScreen`, `PrinterFormScreen`, `SharePrintScreen`, `PrintHistoryScreen`, overlay-permission dialog, unlink dialog, `PrintStatusDialog` done message, iOS display name, widget test.
- Verify: `MarginFields`, `PaperWidthSelector` (unchanged widgets, still inside the form). `lib/system_print_main.dart` still compiles; it does not need `BoletaPage`.
- Exclude: `lib/services/**` print/USB/Bluetooth transports (except no edits at all). `lib/services/print_service.dart` job title `Pagina de prueba` and `lib/services/escpos_test_page.dart` thermal text stay. `android/**` including `print_overlay.xml` Holo overlay and `print_settings.xml`. Dark theme. New fonts. Accessibility pass beyond `SafeArea`. iOS print/share/Bluetooth/USB feature work.

## Validation

- Product: user can still list printers, add/edit, test print, unlink, open history, share-print select printer. USB remains selectable on Android. Overlay permission prompt remains Android-only.
- Interface: compact ~360×640 (phone / Falcon portrait): list + FAB, form bar visible. Medium ~700: fields capped at 600. Expanded ~840+ landscape: list-detail or 600-wide fallback. iOS: no USB segment, no overlay dialog, `SafeArea` on bars, launcher name `Boleta Print`. Empty list, busy test spinner on a card, share with zero printers.
- System: one `boletaPrintTheme`. No new `Colors.teal` literals. Segment and empty-state connection words come from `PrinterLinkType.label`. No second button style for Guardar/Imprimir.
- Repository: `flutter test test/widget_test.dart` → pass. `flutter analyze lib/app.dart lib/theme.dart lib/widgets lib/screens test/widget_test.dart` → no new issues in those paths.

## Stop conditions

- Stop if the change would add a second color seed, custom font, dark theme, or new radius/spacing token file.
- Stop if layout work starts editing print/USB/Bluetooth success or raster code.
- Stop if iOS work expands past chrome (display name, hiding USB/overlay, SafeArea).
- Stop if expanded list-detail would duplicate printer list state or fail `_reload` after save; ship medium 600-wide stack for all widths ≥ 600 instead.

## Design documentation

- After this shell is merged and the checks above pass: create repo-root `DESIGN.md` with only evidenced rules (teal Material 3 seed, compact/medium/expanded 600/840, `FilledButton` primary / `OutlinedButton` secondary, connection labels from `PrinterLinkType`). Follow `.agents/skills/create-design-md/SKILL.md` including lint and export. Do not write `DESIGN.md` in the same change as this UI work.
