import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hello_world_app/screens/printer_list_screen.dart';
import 'package:hello_world_app/screens/share_print_screen.dart';
import 'package:hello_world_app/screens/sunat_print_settings_screen.dart';
import 'package:hello_world_app/services/print_service.dart';
import 'package:hello_world_app/services/printer_store.dart';
import 'package:hello_world_app/services/sunat/sunat_logo.dart';
import 'package:hello_world_app/services/sunat/sunat_print_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists format, note, and logo across a new store', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SunatPrintStore();
    await store.save(
      const SunatPrintSettings(
        format: SunatTicketFormat.detallado,
        footerNote: '  Pago al contado  ',
        showQr: false,
        showLegend: false,
      ),
    );
    await store.saveLogo(_pngSquare());

    final again = SunatPrintStore();
    final loaded = await again.load();
    expect(loaded.format, SunatTicketFormat.detallado);
    expect(loaded.footerNote, 'Pago al contado');
    expect(loaded.showQr, isFalse);
    expect(loaded.showLegend, isFalse);
    final logo = await again.loadLogoBytes();
    expect(logo, isNotNull);
    final decoded = img.decodeImage(logo!);
    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(SunatLogo.storedMaxWidth));

    await again.clearLogo();
    expect(await again.loadLogoBytes(), isNull);
    final kept = await again.load();
    expect(kept.footerNote, 'Pago al contado');
  });

  test('job note override does not change the saved default', () {
    const saved = SunatPrintSettings(footerNote: 'Nota guardada');
    expect(saved.forJob(null).footerNote, 'Nota guardada');
    expect(saved.forJob('Mesa 4').footerNote, 'Mesa 4');
    expect(saved.forJob('   ').footerNote, isEmpty);
    expect(saved.footerNote, 'Nota guardada');
  });

  test('transparent logo flattens onto white instead of black', () {
    final src = img.Image(width: 8, height: 8, numChannels: 4);
    img.fill(src, color: img.ColorRgba8(0, 0, 0, 0));
    src.setPixel(3, 3, img.ColorRgba8(0, 0, 0, 255));
    final flat = SunatLogo.flattenOnWhite(src);
    final clear = flat.getPixel(0, 0);
    final ink = flat.getPixel(3, 3);
    expect(clear.r, greaterThan(250));
    expect(ink.r, lessThan(5));
  });

  testWidgets('settings screen saves the footer note', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('es'),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('es'), Locale('en')],
        home: SunatPrintSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ticket SUNAT'), findsOneWidget);
    expect(find.text('Nota al pie'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Gracias, vuelva pronto');
    await tester.tap(find.text('Guardar'));
    await tester.pump();

    final loaded = await SunatPrintStore().load();
    expect(loaded.footerNote, 'Gracias, vuelva pronto');
    expect(loaded.format, SunatTicketFormat.claro);
  });

  testWidgets('printer list opens SUNAT ticket settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _esApp(
        PrinterListScreen(
          store: PrinterStore(),
          printService: PrintService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    if (find.text('Después').evaluate().isNotEmpty) {
      await tester.tap(find.text('Después'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Ayuda y legal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ticket SUNAT'));
    await tester.pumpAndSettle();

    expect(find.text('Logo de la empresa'), findsOneWidget);
    expect(find.text('Elegir imagen'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
  });

  testWidgets('share screen edits the saved SUNAT note only for xml', (tester) async {
    SharedPreferences.setMockInitialValues({
      SunatPrintStore.settingsKey: jsonEncode(
        const SunatPrintSettings(footerNote: 'Nota guardada').toJson(),
      ),
    });
    final store = PrinterStore();
    final service = PrintService();

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _esApp(
        SharePrintScreen(
          filePath: '/tmp/comprobante.xml',
          printerStore: store,
          printService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nota del ticket'), findsOneWidget);
    expect(find.text('Nota guardada'), findsOneWidget);
    expect(find.text('Configurar ticket SUNAT'), findsOneWidget);

    await tester.pumpWidget(
      _esApp(
        SharePrintScreen(
          filePath: '/tmp/boleta.pdf',
          printerStore: store,
          printService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nota del ticket'), findsNothing);
  });
}

Widget _esApp(Widget home) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('es'), Locale('en')],
    home: home,
  );
}

Uint8List _pngSquare() {
  final image = img.Image(width: 24, height: 16, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(0, 0, 0));
  return Uint8List.fromList(img.encodePng(image));
}
