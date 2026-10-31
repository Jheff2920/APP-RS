import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hello_world_app/models/paper_width.dart';
import 'package:hello_world_app/models/saved_printer.dart';
import 'package:hello_world_app/services/label_print.dart';
import 'package:hello_world_app/services/print_service.dart';
import 'package:hello_world_app/services/printer_store.dart';
import 'package:hello_world_app/services/redpos/redpos_license.dart';
import 'package:hello_world_app/services/transports/printer_transport.dart';
import 'package:hello_world_app/services/transports/printer_transport_factory.dart';

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

  test('failed preparation waits for an in-flight connection before releasing the next job', () async {
    final events = <String>[];
    final payloads = <List<int>>[];
    PrinterTransportFactory.testOverride = (_) => _Transport(events, payloads,
      connectDelay: const Duration(milliseconds: 25));
    final service = PrintService();
    final failed = expectLater(service.printSharedFile(printer: receipt(),
      filePath: 'build/nonexistent-logical-printer-test-file.pdf'), throwsA(anything));
    final next = service.printTestPage(labels());
    await Future.wait([failed, next]);
    await service.pendingHistoryWrites;
    expect(events, ['open:receipt', 'close:receipt', 'open:labels', 'write:labels', 'close:labels']);
    expect(payloads, hasLength(1));
  });
}
