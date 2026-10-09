import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hello_world_app/models/paper_width.dart';
import 'package:hello_world_app/models/print_job_record.dart';
import 'package:hello_world_app/models/saved_printer.dart';
import 'package:hello_world_app/screens/printer_list_screen.dart';
import 'package:hello_world_app/screens/privacy_data_screen.dart';
import 'package:hello_world_app/services/custom_ticket/custom_ticket_store.dart';
import 'package:hello_world_app/services/print_history_store.dart';
import 'package:hello_world_app/services/print_service.dart';
import 'package:hello_world_app/services/printer_store.dart';
import 'package:hello_world_app/services/redpos/redpos_code.dart';
import 'package:hello_world_app/services/redpos/redpos_license.dart';
import 'package:hello_world_app/services/transports/printer_transport.dart';
import 'package:hello_world_app/services/transports/printer_transport_factory.dart';
import 'package:hello_world_app/theme.dart';

/// Recorridos de punta a punta, sin hardware: la impresora es un transporte
/// falso que guarda los bytes que recibiría.
class _FakeTransport implements PrinterTransport {
  _FakeTransport(this.log, this.failWith);

  final List<List<int>> log;
  final String? failWith;

  @override
  Future<void> connect(SavedPrinter printer) async {
    if (failWith != null) throw PrinterTransportException(failWith!);
  }

  @override
  Future<void> writeBytes(List<int> bytes) async => log.add(List.of(bytes));

  @override
  Future<void> disconnect() async {}
}

final _sent = <List<int>>[];
String? _failWith;
late Directory _tmp;

SavedPrinter _lan({bool isDefault = true}) => SavedPrinter(
      id: 'lan',
      name: 'Caja principal',
      type: PrinterLinkType.network,
      address: '192.168.1.50',
      paper: PaperWidth.mm80,
      isDefault: isDefault,
    );

SavedPrinter _bt() => SavedPrinter(
      id: 'bt',
      name: 'Cocina',
      type: PrinterLinkType.bluetooth,
      address: '86:67:7A:02:34:8C',
      paper: PaperWidth.mm58,
    );

Future<void> _prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues({...values});
  final p = await SharedPreferences.getInstance();
  RedPosLicenseStore.instance.resetForTest(prefs: p);
}

/// Texto legible dentro de los bytes ESC/POS.
String _visible(List<int> bytes) => String.fromCharCodes(
      bytes.where((b) => (b >= 32 && b < 127) || b == 10),
    );

int _indexOf(List<int> data, List<int> pattern, [int from = 0]) {
  for (var i = from; i <= data.length - pattern.length; i++) {
    var ok = true;
    for (var j = 0; j < pattern.length; j++) {
      if (data[i + j] != pattern[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}

Uint8List _png({int w = 240, int h = 160}) {
  final image = img.Image(width: w, height: h, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  img.fillRect(
    image,
    x1: 20,
    y1: 20,
    x2: w - 20,
    y2: 60,
    color: img.ColorRgb8(0, 0, 0),
  );
  return Uint8List.fromList(img.encodePng(image));
}

Future<String> _write(String name, List<int> bytes) async {
  final f = File('${_tmp.path}/$name');
  await f.writeAsBytes(bytes);
  return f.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Los textos salen según el idioma del equipo: las pruebas usan español.
    final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
    dispatcher.localeTestValue = const Locale('es');
    dispatcher.localesTestValue = const [Locale('es')];
    addTearDown(dispatcher.clearLocaleTestValue);
    addTearDown(dispatcher.clearLocalesTestValue);
    _sent.clear();
    _failWith = null;
    PrinterTransportFactory.testOverride =
        (_) => _FakeTransport(_sent, _failWith);
    _tmp = Directory.systemTemp.createTempSync('app_flows_');
  });

  tearDown(() {
    PrinterTransportFactory.testOverride = null;
    if (_tmp.existsSync()) _tmp.deleteSync(recursive: true);
  });

  group('impresión (servicio con impresora falsa)', () {
    test('página de prueba: llega a la impresora y queda en el historial',
        () async {
      await _prefs();
      final service = PrintService();
      await service.printTestPage(_lan());
      await service.pendingHistoryWrites;

      expect(_sent, hasLength(1));
      expect(_sent.first.take(2), [0x1b, 0x40], reason: 'empieza con ESC @');
      final jobs = await PrintHistoryStore().loadAll();
      expect(jobs, hasLength(1));
      expect(jobs.first.title, 'Página de prueba');
      expect(jobs.first.status, PrintJobStatus.success);
    });

    test('imagen PNG: raster y margen superior por red', () async {
      await _prefs();
      final path = await _write('captura.png', _png());
      await PrintService().printSharedFile(printer: _lan(), filePath: path);

      final bytes = _sent.single;
      final feed = _indexOf(bytes, [0x1b, 0x4a, 24]);
      final raster = _indexOf(bytes, [0x1d, 0x76, 0x30]);
      expect(feed, greaterThanOrEqualTo(0), reason: 'margen superior ESC J');
      expect(raster, greaterThan(feed), reason: 'la imagen va después');
    });

    test('captura sin extensión se reconoce por su contenido', () async {
      await _prefs();
      final path = await _write('compartido_1700000000', _png());
      await PrintService().printSharedFile(printer: _lan(), filePath: path);
      expect(_indexOf(_sent.single, [0x1d, 0x76, 0x30]), greaterThan(0));
    });

    test('captura con extensión equivocada también se imprime', () async {
      await _prefs();
      final path = await _write('yape.bin', _png());
      await PrintService().printSharedFile(printer: _lan(), filePath: path);
      expect(_indexOf(_sent.single, [0x1d, 0x76, 0x30]), greaterThan(0));
    });

    test('XML de SUNAT: imprime el comprobante', () async {
      await _prefs();
      final path = await _write('20123456789-03-B001-00001234.xml', utf8.encode(_boleta));
      await PrintService().printSharedFile(printer: _lan(), filePath: path);
      final text = _visible(_sent.single);
      expect(text, contains('LIMAFAC SAC'));
      expect(text, contains('B001-00001234'));
    });

    test('formato no soportado: mensaje claro y queda como fallido', () async {
      await _prefs();
      final path = await _write('notas.txt', 'hola'.codeUnits);
      final service = PrintService();
      await expectLater(
        service.printSharedFile(printer: _lan(), filePath: path),
        throwsA(
          isA<PrinterTransportException>()
              .having((e) => e.message, 'mensaje', contains('Formato no soportado')),
        ),
      );
      await service.pendingHistoryWrites;
      expect(_sent, isEmpty);
      final jobs = await PrintHistoryStore().loadAll();
      expect(jobs.single.status, PrintJobStatus.failed);
    });

    test('impresora apagada: error claro, nada se envía y queda fallido',
        () async {
      await _prefs();
      _failWith = 'No se pudo conectar con la impresora (tiempo agotado).';
      final service = PrintService();
      await expectLater(
        service.printTestPage(_lan()),
        throwsA(isA<PrinterTransportException>()),
      );
      await service.pendingHistoryWrites;
      expect(_sent, isEmpty);
      final jobs = await PrintHistoryStore().loadAll();
      expect(jobs.single.status, PrintJobStatus.failed);
      expect(jobs.single.error, contains('No se pudo conectar'));
    });

    test('dirección vacía: pide la dirección en vez de intentar conectar',
        () async {
      await _prefs();
      final empty = _lan().copyWith(address: '');
      await expectLater(
        PrintService().printTestPage(empty),
        throwsA(
          isA<PrinterTransportException>()
              .having((e) => e.message, 'mensaje', contains('dirección')),
        ),
      );
    });

    test('tickets propios: bloqueado sin código, imprime con código',
        () async {
      await _prefs();
      final store = CustomTicketStore();
      final t = await store.create(name: 'Recibo');
      final template = t.copyWith(companyName: 'MI TIENDA DEMO');

      await expectLater(
        PrintService().printCustomTicket(printer: _lan(), template: template),
        throwsA(
          isA<PrinterTransportException>()
              .having((e) => e.message, 'mensaje', contains('función de pago')),
        ),
      );
      expect(_sent, isEmpty);

      await _prefs({RedPosLicenseStore.playEntitlementKey: true});
      await PrintService().printCustomTicket(printer: _lan(), template: template);
      expect(_visible(_sent.single), contains('MI TIENDA DEMO'));
    });

    test('sin código el ticket lleva el pie de publicidad; con código no',
        () async {
      await _prefs();
      await PrintService().printTestPage(_lan());
      final withAds = _sent.single.length;
      _sent.clear();

      await _prefs({RedPosLicenseStore.playEntitlementKey: true});
      await PrintService().printTestPage(_lan());
      expect(_sent.single.length, lessThan(withAds));
    });
  });

  group('pantallas (recorridos de usuario)', () {
    Future<void> setView(WidgetTester t, Size size) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = size;
      t.platformDispatcher.localeTestValue = const Locale('es');
      t.platformDispatcher.localesTestValue = const [Locale('es')];
      addTearDown(() {
        t.view.reset();
        t.platformDispatcher.clearLocaleTestValue();
        t.platformDispatcher.clearLocalesTestValue();
      });
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async => switch (call.method) {
          'checkPermissionStatus' || 'checkServiceStatus' => 1,
          'requestPermissions' => <int, int>{},
          'shouldShowRequestPermissionRationale' => false,
          _ => null,
        },
      );
      m.setMockMethodCallHandler(
        const MethodChannel('boleta_print/printers_prefs'),
        (call) async => null,
      );
      m.setMockMethodCallHandler(
        const MethodChannel('boleta_print/bt_bond'),
        (call) async => switch (call.method) {
          'listBonded' => <dynamic>[],
          'startScan' => true,
          _ => null,
        },
      );
    }

    Widget app(Widget home) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: boletaPrintTheme,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home,
        );

    /// Alterna tiempo real (archivos, preferencias) con cuadros de pantalla.
    Future<void> settle(WidgetTester t, {int rounds = 30}) async {
      for (var i = 0; i < rounds; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await t.pump(const Duration(milliseconds: 60));
      }
    }

    Future<void> tapText(WidgetTester t, String text) async {
      final f = find.text(text);
      if (f.evaluate().isEmpty) {
        await t.scrollUntilVisible(
          f,
          150,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
      }
      await t.ensureVisible(f.first);
      await t.pump(const Duration(milliseconds: 80));
      await t.tap(f.hitTestable().first);
      await settle(t, rounds: 8);
    }

    Future<void> typeInto(WidgetTester t, String label, String text) async {
      final f = find.widgetWithText(TextFormField, label);
      if (f.evaluate().isEmpty) {
        await t.scrollUntilVisible(
          f,
          150,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
      }
      await t.ensureVisible(f.first);
      await t.enterText(f.first, text);
      await t.pump(const Duration(milliseconds: 80));
    }

    PrinterListScreen home() => PrinterListScreen(
          store: PrinterStore(),
          printService: PrintService(),
        );

    testWidgets('vincular una impresora WiFi: probar y guardar', (t) async {
      await _prefs();
      await setView(t, const Size(412, 915));
      await t.pumpWidget(app(home()));
      await settle(t, rounds: 6);

      await tapText(t, 'Vincular impresora');
      await tapText(t, 'WiFi');
      await typeInto(t, 'IP de la impresora', '192.168.1.77');
      await typeInto(t, 'Ej.: Caja 1', 'Barra');

      await tapText(t, 'Probar');
      await settle(t, rounds: 40);
      expect(find.text('Página de prueba enviada'), findsOneWidget);
      expect(_sent, hasLength(1));

      await tapText(t, 'Guardar');
      await settle(t, rounds: 10);
      final saved = (await t.runAsync(() => PrinterStore().loadAll()))!;
      expect(saved.map((p) => p.name), contains('Barra'));
      expect(saved.single.address, '192.168.1.77');
      // De vuelta en el inicio, con la impresora en la lista.
      expect(find.text('Barra'), findsWidgets);
    });

    testWidgets('probar desde el inicio: confirma y registra', (t) async {
      await _prefs();
      await setView(t, const Size(412, 915));
      await t.runAsync(() => PrinterStore().upsert(_lan()));
      await t.pumpWidget(app(home()));
      await settle(t, rounds: 6);

      await tapText(t, 'Probar');
      await settle(t, rounds: 40);
      expect(find.text('Prueba enviada a Caja principal'), findsOneWidget);
      expect(_sent, hasLength(1));
    });

    testWidgets('probar con la impresora apagada: dice qué pasó',
        (t) async {
      await _prefs();
      _failWith = 'No se pudo conectar por WiFi. Revisa que la impresora esté '
          'encendida y la IP sea correcta.';
      await setView(t, const Size(412, 915));
      await t.runAsync(() => PrinterStore().upsert(_lan()));
      await t.pumpWidget(app(home()));
      await settle(t, rounds: 6);

      await tapText(t, 'Probar');
      await settle(t, rounds: 40);
      expect(find.textContaining('No se pudo conectar por WiFi'), findsOneWidget);
      expect(_sent, isEmpty);
    });

    testWidgets('definir principal y desvincular con confirmación',
        (t) async {
      await _prefs();
      await setView(t, const Size(412, 915));
      await t.runAsync(() async {
        final store = PrinterStore();
        await store.upsert(_lan());
        await store.upsert(_bt());
      });
      await t.pumpWidget(app(home()));
      await settle(t, rounds: 6);

      // Opciones de la impresora secundaria (la segunda tarjeta).
      await t.tap(find.byTooltip('Opciones').last);
      await settle(t, rounds: 10);
      await tapText(t, 'Usar como principal');
      var all = (await t.runAsync(() => PrinterStore().loadAll()))!;
      expect(all.firstWhere((p) => p.isDefault).id, 'bt');

      // Cancelar no borra; confirmar sí.
      await t.tap(find.byTooltip('Opciones').last);
      await settle(t, rounds: 10);
      await tapText(t, 'Desvincular');
      await tapText(t, 'Cancelar');
      all = (await t.runAsync(() => PrinterStore().loadAll()))!;
      expect(all, hasLength(2));

      await t.tap(find.byTooltip('Opciones').last);
      await settle(t, rounds: 10);
      await tapText(t, 'Desvincular');
      await t.tap(find.widgetWithText(FilledButton, 'Desvincular'));
      await settle(t, rounds: 15);
      all = (await t.runAsync(() => PrinterStore().loadAll()))!;
      expect(all, hasLength(1));
    });

    testWidgets('código de activación: inválido, luego válido', (t) async {
      await _prefs();
      await setView(t, const Size(412, 915));
      await t.runAsync(() => PrinterStore().upsert(_lan()));
      await t.pumpWidget(app(home()));
      await settle(t, rounds: 6);
      expect(find.text('Versión gratuita'), findsOneWidget);

      await tapText(t, 'Quitar');
      await tapText(t, 'Tengo un código');
      await t.enterText(find.byType(TextField), 'RP-AAAA-BBBB-CCCC');
      await tapText(t, 'Activar');
      await settle(t, rounds: 10);
      expect(find.text('Código no válido'), findsOneWidget);
      expect(find.text('Versión gratuita'), findsOneWidget);

      await t.enterText(find.byType(TextField), RedPosCode.generate());
      await tapText(t, 'Activar');
      await settle(t, rounds: 15);
      expect(find.text('Versión gratuita'), findsNothing);
      expect(
        find.text('Publicidad desactivada en esta instalación'),
        findsOneWidget,
      );
      expect(
        await t.runAsync(
          () => RedPosLicenseStore.instance.isAdsFree(reloadDisk: false),
        ),
        isTrue,
      );
    });

    testWidgets('Datos y privacidad: borrar datos locales', (t) async {
      await _prefs();
      await setView(t, const Size(412, 915));
      await t.runAsync(() => PrinterStore().upsert(_lan()));
      await t.pumpWidget(app(PrivacyDataScreen(store: PrinterStore())));
      await settle(t, rounds: 6);

      await tapText(t, 'Borrar datos locales');
      await t.tap(find.widgetWithText(FilledButton, 'Borrar'));
      await settle(t, rounds: 20);
      expect(find.textContaining('Datos locales borrados'), findsOneWidget);
      expect(await t.runAsync(() => PrinterStore().loadAll()), isEmpty);
    });

    testWidgets('tablet: Atrás cierra el panel y no la app', (t) async {
      await _prefs();
      await setView(t, const Size(1280, 800));
      await t.runAsync(() => PrinterStore().upsert(_lan()));
      await t.pumpWidget(app(home()));
      await settle(t, rounds: 6);
      expect(find.text('Ajustes y detalle'), findsOneWidget);

      await t.tap(find.byTooltip('Opciones de la impresora'));
      await settle(t, rounds: 10);
      await tapText(t, 'Ajustes de la impresora');
      expect(find.text('Ajustes y detalle'), findsNothing);
      expect(find.text('Guardar'), findsOneWidget);

      final handled = await t.binding.handlePopRoute();
      await settle(t, rounds: 10);
      expect(handled, isTrue, reason: 'Atrás lo atiende el panel');
      expect(find.text('Ajustes y detalle'), findsOneWidget);
    });

    testWidgets('teléfono: Atrás vuelve del formulario al inicio', (t) async {
      await _prefs();
      await setView(t, const Size(412, 915));
      await t.runAsync(() => PrinterStore().upsert(_lan()));
      await t.pumpWidget(app(home()));
      await settle(t, rounds: 6);

      await t.tap(find.byTooltip('Opciones de la impresora'));
      await settle(t, rounds: 10);
      await tapText(t, 'Ajustes de la impresora');
      expect(find.text('Guardar'), findsOneWidget);

      await t.tap(find.byTooltip('Atrás'));
      await settle(t, rounds: 10);
      expect(find.text('Guardar'), findsNothing);
      expect(find.text('Caja principal'), findsWidgets);
    });

    testWidgets('teléfono en horizontal: una sola columna', (t) async {
      await _prefs();
      await setView(t, const Size(915, 412));
      await t.runAsync(() => PrinterStore().upsert(_lan()));
      await t.pumpWidget(app(home()));
      await settle(t, rounds: 6);
      // El panel "Ajustes y detalle" es solo de tablets.
      expect(find.text('Ajustes y detalle'), findsNothing);
      expect(find.text('Imprimir archivo'), findsOneWidget);
    });
  });
}

const _boleta = '''
<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>B001-00001234</cbc:ID>
  <cbc:IssueDate>2026-09-08</cbc:IssueDate>
  <cbc:IssueTime>14:05:09</cbc:IssueTime>
  <cbc:InvoiceTypeCode listID="0104">03</cbc:InvoiceTypeCode>
  <cbc:DocumentCurrencyCode>PEN</cbc:DocumentCurrencyCode>
  <cac:AccountingSupplierParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="6">20123456789</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>LIMAFAC SAC</cbc:RegistrationName>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingSupplierParty>
  <cac:AccountingCustomerParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="1">45678912</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>JUAN PEREZ</cbc:RegistrationName>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingCustomerParty>
  <cac:TaxTotal>
    <cbc:TaxAmount currencyID="PEN">3.24</cbc:TaxAmount>
  </cac:TaxTotal>
  <cac:LegalMonetaryTotal>
    <cbc:LineExtensionAmount currencyID="PEN">18.00</cbc:LineExtensionAmount>
    <cbc:PayableAmount currencyID="PEN">21.24</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>
  <cac:InvoiceLine>
    <cbc:InvoicedQuantity unitCode="NIU">2</cbc:InvoicedQuantity>
    <cbc:LineExtensionAmount currencyID="PEN">12.00</cbc:LineExtensionAmount>
    <cac:Item><cbc:Description>CAFE AMERICANO</cbc:Description></cac:Item>
    <cac:Price><cbc:PriceAmount currencyID="PEN">6.00</cbc:PriceAmount></cac:Price>
  </cac:InvoiceLine>
</Invoice>
'''
    ;
