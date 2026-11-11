import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hello_world_app/models/paper_width.dart';
import 'package:hello_world_app/models/saved_printer.dart';
import 'package:hello_world_app/screens/share_print_screen.dart';
import 'package:hello_world_app/services/escpos_pdf_print.dart';
import 'package:hello_world_app/services/label_print.dart';
import 'package:hello_world_app/services/print_service.dart';
import 'package:hello_world_app/services/printer_store.dart';
import 'package:hello_world_app/services/redpos/redpos_license.dart';
import 'package:hello_world_app/services/transports/printer_transport.dart';
import 'package:hello_world_app/services/transports/printer_transport_factory.dart';
import 'package:hello_world_app/widgets/logical_printer_settings.dart';

SavedPrinter receipt() => SavedPrinter(
    id: 'receipt',
    name: 'HQ300-Recibos',
    type: PrinterLinkType.network,
    address: '192.168.1.50',
    paper: PaperWidth.mm80);
SavedPrinter labels() => SavedPrinter(
    id: 'labels',
    name: 'HQ300-Etiquetas',
    type: PrinterLinkType.network,
    address: '192.168.1.50',
    paper: PaperWidth.mm80,
    kind: PrinterKind.label);

class _Transport implements PrinterTransport {
  _Transport(this.events, this.payloads, {this.connectDelay = Duration.zero});
  final List<String> events;
  final List<List<int>> payloads;
  final Duration connectDelay;
  late String id;
  @override
  Future<void> connect(SavedPrinter p) async {
    id = p.id;
    if (connectDelay != Duration.zero) await Future<void>.delayed(connectDelay);
    events.add('open:$id');
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    events.add('write:$id');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    payloads.add(bytes);
  }

  @override
  Future<void> disconnect() async {
    events.add('close:$id');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PrinterStore store;
  late SharedPreferences prefs;
  final snapshots = <List<dynamic>>[];
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    RedPosLicenseStore.instance.resetForTest(prefs: prefs);
    store = PrinterStore(prefs: prefs);
    snapshots.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('boleta_print/printers_prefs'), (call) async {
      if (call.method == 'syncPrintersJson') {
        snapshots.add(jsonDecode(call.arguments as String) as List);
      }
      return null;
    });
  });
  tearDown(() {
    PrinterTransportFactory.testOverride = null;
  });

  test('one physical connection persists two stable Android destinations',
      () async {
    await store.upsert(receipt());
    await store.upsert(labels());
    final all = await PrinterStore().loadAll();
    expect(all.map((p) => p.id), ['receipt', 'labels']);
    expect(all.map((p) => p.physicalPrinterId).toSet(), hasLength(1));
    final catalog = jsonDecode(prefs.getString('printer_catalog_v2')!) as Map;
    expect(catalog['physicalPrinters'], hasLength(1));
    expect(catalog['logicalPrinters'], hasLength(2));
    expect(
        (catalog['logicalPrinters'] as List)
            .every((p) => !(p as Map).containsKey('address')),
        isTrue);
    expect(snapshots.last.map((p) => p['name']),
        ['HQ300-Recibos', 'HQ300-Etiquetas']);
    expect(all.first.enabledProfiles.every((p) => !p.isLabel), isTrue);
    expect(all.last.enabledProfiles.every((p) => p.isLabel), isTrue);
  });

  test('renaming and adding a label profile never changes receipt settings',
      () async {
    await store.upsert(receipt());
    await store.upsert(labels());
    final before = (await store.loadAll()).first.toJson();
    final label = (await store.loadAll()).last;
    await store.upsert(label.copyWith(name: 'Precios', paperProfiles: [
      ...label.paperProfiles,
      const PaperProfile(
          paperProfileId: 'custom',
          logicalPrinterId: 'labels',
          name: '40 × 30 mm',
          widthMm: 40,
          heightMm: 30)
    ]));
    final after = await store.loadAll();
    expect(after.first.toJson(), before);
    expect(after.last.id, 'labels');
    expect(after.last.paperProfiles, hasLength(3));
  });

  test('legacy migration preserves ID, all settings, media IDs and backup',
      () async {
    final old = receipt().copyWith(isDefault: true).toJson()
      ..remove('physicalPrinterId')
      ..remove('kind')
      ..remove('protocol')
      ..remove('paperProfiles')
      ..remove('defaultPaperProfileId');
    final raw = jsonEncode([old]);
    await prefs.setString('saved_printers_v1', raw);
    final migrated = (await store.loadAll()).single;
    for (final entry in old.entries) {
      expect(migrated.toJson()[entry.key], entry.value);
    }
    expect(migrated.enabledProfiles.map((p) => p.mediaId), [
      'BOLETA_ROLL_58',
      'BOLETA_ROLL_58_MAX',
      'BOLETA_ROLL_58_GOOGLE',
      'BOLETA_ROLL_80',
      'BOLETA_ROLL_80_MAX',
      'BOLETA_ROLL_80_GOOGLE'
    ]);
    expect(prefs.getString('saved_printers_v1'), raw);
    await store.upsert(labels());
    expect(await store.loadAll(), hasLength(2));
  });

  test('concurrent saves and license updates preserve both destinations',
      () async {
    await Future.wait(
        [store.upsert(receipt()), PrinterStore().upsert(labels())]);
    await Future.wait(
        [store.applyAdsFree(true), PrinterStore().setDefault('labels')]);
    final all = await store.loadAll();
    expect(all, hasLength(2));
    expect(all.every((p) => p.adsFree), isTrue);
    expect(all.singleWhere((p) => p.isDefault).id, 'labels');
  });

  test(
      'legacy accidental duplicates retain valid profiles for the surviving ID',
      () async {
    final old = receipt().copyWith(isDefault: true).toJson();
    final duplicate = {...old, 'id': 'duplicate', 'name': 'Latest name'};
    for (final row in [old, duplicate]) {
      row.remove('physicalPrinterId');
      row.remove('paperProfiles');
      row.remove('kind');
    }
    await prefs.setString('saved_printers_v1', jsonEncode([old, duplicate]));
    final migrated = (await store.loadAll()).single;
    expect(migrated.id, 'receipt');
    expect(migrated.name, 'Latest name');
    expect(migrated.enabledProfiles, hasLength(6));
    expect(
        migrated.enabledProfiles.every((p) => p.logicalPrinterId == 'receipt'),
        isTrue);
  });

  test('deleting one logical printer keeps the other and physical connection',
      () async {
    await store.upsert(receipt());
    await store.upsert(labels());
    final hardwareId = (await store.loadAll()).last.physicalPrinterId;
    await store.delete('receipt');
    final remaining = (await store.loadAll()).single;
    expect(remaining.id, 'labels');
    expect(remaining.physicalPrinterId, hardwareId);
    expect(PrinterStore.findByIdOrDefault([remaining], 'receipt'), isNull);
    expect(PrinterStore.findByIdOrDefault([remaining], ''), remaining);
  });

  test(
      'physical connection edit propagates without renaming another logical printer',
      () async {
    await store.upsert(receipt());
    await store.upsert(labels());
    final label = (await store.loadAll()).last;
    await store.upsert(label.copyWith(address: '192.168.1.60'));
    final all = await store.loadAll();
    expect(all.map((p) => p.address).toSet(), {'192.168.1.60'});
    expect(all.first.name, 'HQ300-Recibos');
  });

  test('foreign profiles and empty enabled sizes are rejected', () async {
    await expectLater(
        store.upsert(labels().copyWith(paperProfiles: receipt().paperProfiles)),
        throwsArgumentError);
    await expectLater(store.upsert(labels().copyWith(paperProfiles: [])),
        throwsArgumentError);
  });

  test('paper resolution is exact; a receipt ID cannot select a label profile',
      () {
    final p = labels();
    expect(
        LabelPrint.resolveProfile(p, p.paperProfiles.last.mediaId).widthMm, 30);
    expect(() => LabelPrint.resolveProfile(p, 'BOLETA_ROLL_80'),
        throwsA(isA<PrinterTransportException>()));
    expect(LabelPrint.isRotated(p.defaultProfile, 1968, 984), isFalse);
    expect(LabelPrint.isRotated(p.defaultProfile, 984, 1968), isTrue);
  });

  test('label raster keeps the complete physical page and blank margins', () {
    final p = labels();
    final profile = p.defaultProfile;
    final source = img.Image(width: 400, height: 200);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(source,
        x1: 100, y1: 50, x2: 140, y2: 70, color: img.ColorRgb8(0, 0, 0));
    final bytes = LabelPrint.encodePage(p, profile, source);
    expect(bytes.take(2), [0x1b, 0x40]);
    final stride = bytes[6] + (bytes[7] << 8);
    final height = bytes[8] + (bytes[9] << 8);
    expect(stride, 50);
    expect(height, 200);
    expect(bytes.sublist(10, 10 + stride * 40).every((b) => b == 0), isTrue);
    expect(bytes.sublist(10, 10 + stride * height).any((b) => b != 0), isTrue);
    expect(bytes.length,
        10 + stride * height + 3); // only GAP feed, no receipt footer/cut
  });

  test('50 mm label on a 58 mm head prints its centre; wider than roll fails',
      () {
    final p = labels().copyWith(paper: PaperWidth.mm58);
    final source = img.Image(width: 400, height: 200);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));
    final ink = img.ColorRgb8(0, 0, 0);
    img.fillRect(source, x1: 0, y1: 0, x2: 7, y2: 199, color: ink); // 1 mm edge
    img.fillRect(source,
        x1: 20, y1: 0, x2: 27, y2: 199, color: ink); // 2.5 mm in
    final bytes = LabelPrint.encodePage(p, p.defaultProfile, source);
    final stride = bytes[6] + (bytes[7] << 8);
    expect(stride, 48); // 384 dots = the 58 mm head, not the 400-dot label
    expect(bytes.sublist(10, 13), [0x00, 0x0f, 0xf0]);
    const wide = PaperProfile(
        paperProfileId: 'wide',
        logicalPrinterId: 'labels',
        name: '60 × 25 mm',
        widthMm: 60,
        heightMm: 25);
    expect(() => LabelPrint.encodePage(p, wide, source),
        throwsA(isA<PrinterTransportException>()));
  });

  test('orientation turns the content clockwise and is saved with the size',
      () {
    final p = labels();
    final source = img.Image(width: 400, height: 200);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(source,
        x1: 0, y1: 0, x2: 39, y2: 19, color: img.ColorRgb8(0, 0, 0));
    PaperProfile turned(int rotation) => PaperProfile.fromJson(
        {...p.defaultProfile.toJson(), 'rotation': rotation});
    int at(List<int> bytes, int row, int byte) => bytes[10 + row * 50 + byte];

    final upsideDown = LabelPrint.encodePage(p, turned(180), source);
    expect(at(upsideDown, 0, 0), 0);
    expect(at(upsideDown, 199, 49), 0xff); // top-left mark is now bottom-right

    // 90°: the 400×200 page stands up (100×200 on the label); the top-left
    // mark goes to its top-right corner, not to the bottom-left.
    final sideways = LabelPrint.encodePage(p, turned(90), source);
    expect(at(sideways, 5, 11) | at(sideways, 5, 12), isNot(0));
    expect(at(sideways, 195, 0), 0);

    expect(PaperProfile.fromJson(turned(270).toJson()).rotation, 270);
    expect(turned(45).validationError, isNotNull);
  });

  testWidgets('print screen: a label printer offers copies and shows the total',
      (t) async {
    await t.runAsync(() => store.upsert(labels()));
    final dir = await t.runAsync(
        () => Directory.systemTemp.createTemp('label-copies-ui'));
    final file = File('${dir!.path}/etiqueta.png');
    await t.runAsync(() async {
      final source = img.Image(width: 20, height: 10);
      img.fill(source, color: img.ColorRgb8(255, 255, 255));
      await file.writeAsBytes(img.encodePng(source));
    });
    addTearDown(() => dir.delete(recursive: true));
    await t.pumpWidget(MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: SharePrintScreen(
            filePath: file.path,
            printerStore: store,
            printService: PrintService())));
    await t.pumpAndSettle();
    expect(find.text('Etiquetas a imprimir'), findsOneWidget);
    expect(find.text('Total: 1 etiqueta'), findsOneWidget);
    await t.ensureVisible(find.byTooltip('Más copias'));
    await t.tap(find.byTooltip('Más copias'));
    await t.tap(find.byTooltip('Más copias'));
    await t.pump();
    expect(find.text('Total: 3 etiquetas'), findsOneWidget);
  });

  // NOTA: no se agrega una prueba de widget para "Copias: N (todas las
  // páginas)" cuando un .pdf falla al abrir, porque pdfx no tiene plugin
  // nativo en `flutter test` y el reintento de ese canal de plataforma
  // dentro de un segundo pumpWidget resulta muy sensible al orden exacto de
  // pumps (a veces no asienta dentro de pumpAndSettle). El texto se revisó
  // a mano junto con los revisores externos; la ruta común (PNG/JPG, 1
  // página) sí queda cubierta arriba.

  test('darkness: TSPL sends DENSITY and light greys become ink; 0 keeps both',
      () {
    final tspl = labels().copyWith(protocol: PrinterProtocol.tspl);
    final grey = img.Image(width: 400, height: 200);
    img.fill(grey, color: img.ColorRgb8(200, 200, 200)); // light grey text
    PaperProfile dark(int level) => PaperProfile.fromJson(
        {...tspl.defaultProfile.toJson(), 'darkness': level});
    String header(List<int> bytes) =>
        latin1.decode(bytes.sublist(0, 140), allowInvalid: true);

    final normal = LabelPrint.encodePage(tspl, dark(0), grey);
    expect(header(normal), isNot(contains('DENSITY')));
    final darkest = LabelPrint.encodePage(tspl, dark(15), grey);
    expect(header(darkest), contains('OFFSET 0 mm\r\nDENSITY 15\r\nCLS\r\n'));

    // ESC/POS has no darkness command: the grey is white at 0, ink at 15.
    final escpos = labels();
    PaperProfile escDark(int level) => PaperProfile.fromJson(
        {...escpos.defaultProfile.toJson(), 'darkness': level});
    expect(LabelPrint.encodePage(escpos, escDark(0), grey)[10], 0x00);
    expect(LabelPrint.encodePage(escpos, escDark(15), grey)[10], 0xff);
    // 8 is the UI's neutral point (switch "Oscuridad personalizada" turns on
    // there): must render exactly like "automatic" (0), never lighter.
    expect(LabelPrint.encodePage(escpos, escDark(8), grey)[10],
        LabelPrint.encodePage(escpos, escDark(0), grey)[10]);

    expect(PaperProfile.fromJson(dark(12).toJson()).darkness, 12);
    expect(dark(16).validationError, isNotNull);
  });

  test('thicken: a 1-dot line prints 2 dots wide; edges do not overflow', () {
    final p = labels();
    final source = img.Image(width: 400, height: 200);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));
    img.drawLine(source,
        x1: 100, y1: 0, x2: 100, y2: 199, color: img.ColorRgb8(0, 0, 0));
    source.setPixelRgb(399, 199, 0, 0, 0); // bottom-right corner dot
    PaperProfile bold(bool on) =>
        PaperProfile.fromJson({...p.defaultProfile.toJson(), 'thicken': on});
    int at(List<int> bytes, int row, int byte) => bytes[10 + row * 50 + byte];

    expect(at(LabelPrint.encodePage(p, bold(false), source), 50, 12), 0x08);
    final thick = LabelPrint.encodePage(p, bold(true), source);
    expect(at(thick, 50, 12), 0x0c); // x = 100 and 101
    expect(at(thick, 199, 49), 0x01); // corner stays inside the label
    expect(PaperProfile.fromJson(bold(true).toJson()).thicken, isTrue);
  });

  test('TSPL sets size and GAP for each page, then prints its bitmap', () {
    final p = labels().copyWith(protocol: PrinterProtocol.tspl);
    final image = img.Image(width: 400, height: 200);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    final bytes = LabelPrint.encodePage(p, p.defaultProfile, image);
    final text = latin1.decode(bytes);
    expect(text, startsWith('SIZE 50.0 mm,25.0 mm\r\nGAP 2.0 mm,0 mm\r\n'));
    expect(text, contains('BITMAP 0,0,50,200,0,'));
    expect(text, endsWith('\r\nPRINT 1,1\r\n'));
    final rasterStart =
        text.indexOf('BITMAP 0,0,50,200,0,') + 'BITMAP 0,0,50,200,0,'.length;
    expect(
        bytes.sublist(rasterStart, rasterStart + 10000).every((b) => b == 255),
        isTrue);
  });

  test('receipt and label jobs share a connection lease and label has no ads',
      () async {
    final events = <String>[];
    final payloads = <List<int>>[];
    PrinterTransportFactory.testOverride = (_) => _Transport(events, payloads);
    final service = PrintService();
    await Future.wait(
        [service.printTestPage(receipt()), service.printTestPage(labels())]);
    await service.pendingHistoryWrites;
    expect(events, [
      'open:receipt',
      'write:receipt',
      'close:receipt',
      'open:labels',
      'write:labels',
      'close:labels'
    ]);
    final expected = await LabelPrint.testPage(labels());
    expect(payloads.last, expected);
  });

  test(
      'failed preparation waits for an in-flight connection before releasing the next job',
      () async {
    final events = <String>[];
    final payloads = <List<int>>[];
    PrinterTransportFactory.testOverride = (_) => _Transport(events, payloads,
        connectDelay: const Duration(milliseconds: 25));
    final service = PrintService();
    final failed = expectLater(
        service.printSharedFile(
            printer: receipt(),
            filePath: 'build/nonexistent-logical-printer-test-file.pdf'),
        throwsA(anything));
    final next = service.printTestPage(labels());
    await Future.wait([failed, next]);
    await service.pendingHistoryWrites;
    expect(events, [
      'open:receipt',
      'close:receipt',
      'open:labels',
      'write:labels',
      'close:labels'
    ]);
    expect(payloads, hasLength(1));
  });

  test('printSharedFile repeats the full label job bytes-for-bytes per copy',
      () async {
    final dir = await Directory.systemTemp.createTemp('label-copies');
    final file = File('${dir.path}/etiqueta.png');
    final source = img.Image(width: 20, height: 10);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));
    await file.writeAsBytes(img.encodePng(source));
    addTearDown(() => dir.delete(recursive: true));

    final events = <String>[];
    final payloads = <List<int>>[];
    PrinterTransportFactory.testOverride = (_) => _Transport(events, payloads);
    final service = PrintService();
    final single = await LabelPrint.build(labels(), filePath: file.path);

    await service.printSharedFile(
        printer: labels(), filePath: file.path, copies: 3);
    await service.pendingHistoryWrites;

    expect(payloads.last, hasLength(single.length * 3));
    expect(payloads.last, [...single, ...single, ...single]);
  });

  test('printSharedFile repeats a receipt ticket per copy', () async {
    final dir = await Directory.systemTemp.createTemp('receipt-copies');
    final file = File('${dir.path}/voucher.png');
    final source = img.Image(width: 40, height: 20);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));
    await file.writeAsBytes(img.encodePng(source));
    addTearDown(() => dir.delete(recursive: true));

    final payloads = <List<int>>[];
    PrinterTransportFactory.testOverride = (_) => _Transport(<String>[], payloads);
    final single =
        await EscPosPdfPrint.buildImageFile(receipt(), filePath: file.path);

    await PrintService().printSharedFile(
        printer: receipt(), filePath: file.path, copies: 2);

    final sent = payloads.last;
    // La publicidad va antes del último corte: la primera copia sale intacta.
    expect(sent.sublist(0, single.length), single);
    expect(sent.sublist(single.length, single.length + 64), single.sublist(0, 64));
    expect(sent.length, greaterThanOrEqualTo(single.length * 2));
  });

  // NOTA: no se agrega aquí una prueba de firstPage/lastPage con un PDF real
  // porque pdfx (pdfium) no tiene mock de canal de plataforma en `flutter
  // test`; LabelPrint.build ya se ejecuta sobre PDFs reales solo en
  // dispositivo/emulador. Las pruebas físicas del rango de páginas quedan
  // pendientes junto con el resto de la validación de hardware (ver
  // docs/IMPRESORAS_LOGICAS.md).

  testWidgets(
      'editing a size with corrupted rotation/darkness does not crash the dialog',
      (t) async {
    // Simula un JSON guardado dañado (edición manual o dato de una versión
    // vieja): rotación fuera de {0,90,180,270} y oscuridad fuera de 0..15.
    final corrupt = PaperProfile.fromJson({
      ...PaperProfile.labels('p1').first.toJson(),
      'rotation': 45,
      'darkness': 99,
    });
    await t.pumpWidget(MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
            body: LogicalPrinterSettings(
                printerId: 'p1',
                kind: PrinterKind.label,
                protocol: PrinterProtocol.escpos,
                profiles: [corrupt],
                defaultProfileId: corrupt.paperProfileId,
                onKindChanged: (_) {},
                onProtocolChanged: (_) {},
                onProfilesChanged: (_) {},
                onDefaultChanged: (_) {}))));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Editar'));
    await t.pumpAndSettle();
    expect(find.text('Editar tamaño'), findsOneWidget);
    // El Dropdown y el Slider no tumban la app con el valor recortado.
    expect(find.text('Vertical'), findsOneWidget);
    expect(find.text('Nivel 15 de 15'), findsOneWidget);
  });

  // NOTA: no se agrega una prueba de widget para "un PDF real con extensión
  // .jpg sigue contando sus páginas por la cabecera" (el fix del bloqueante
  // de la 3ª ronda de revisión) por la misma razón que la nota de arriba:
  // en cuanto la cabecera sintética realmente dice "%PDF-", el código
  // intenta la llamada real a pdfx (PdfDocument.openFile), que no tiene
  // plugin nativo en `flutter test` y no se resuelve de forma confiable
  // dentro de pumpAndSettle ni con un pump de calentamiento previo (se
  // probó y sigue colgando). El fix en sí (lectura síncrona de 5 bytes +
  // detección por %PDF- igual que LabelPrint.build, en vez de por
  // extensión) se verificó a mano y con los revisores externos (Claude
  // Code y Codex); la ruta común sin ambigüedad de extensión (imagen real,
  // 1 página) sí queda cubierta por las pruebas de arriba.
}
