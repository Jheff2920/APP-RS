import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hello_world_app/models/paper_width.dart';
import 'package:hello_world_app/models/saved_printer.dart';
import 'package:hello_world_app/services/custom_ticket/custom_ticket.dart';
import 'package:hello_world_app/services/custom_ticket/custom_ticket_escpos.dart';
import 'package:hello_world_app/services/custom_ticket/custom_ticket_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('template serializes name, lines, codes and logo', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CustomTicketStore();
    final created = await store.create(name: 'Cafeteria');
    final withLogo = created.copyWith(
      title: 'MI NEGOCIO',
      showLogo: true,
      logoBytes: _pngSquare(),
      lines: const [
        CustomTicketLine(
          type: CustomTicketLineType.text,
          text: 'Bienvenido',
          center: true,
          bold: true,
        ),
        CustomTicketLine(
          type: CustomTicketLineType.item,
          text: 'Cafe',
          qty: '2',
          unitPrice: '5.00',
          amount: '10.00',
        ),
      ],
      showTotals: true,
      subtotal: '10.00',
      tax: '1.80',
      total: '11.80',
      showQr: true,
      qrData: 'https://example.com/t/1',
      showBarcode: true,
      barcodeData: 'ABC12345',
      footer: 'Gracias',
    );
    await store.save(withLogo);

    final again = CustomTicketStore();
    final loaded = await again.loadById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Cafeteria');
    expect(loaded.title, 'MI NEGOCIO');
    expect(loaded.lines, hasLength(2));
    expect(loaded.lines.first.center, isTrue);
    expect(loaded.lines.last.amount, '10.00');
    expect(loaded.showQr, isTrue);
    expect(loaded.qrData, 'https://example.com/t/1');
    expect(loaded.showBarcode, isTrue);
    expect(loaded.barcodeData, 'ABC12345');
    expect(loaded.footer, 'Gracias');
    expect(loaded.logoBytes, isNotNull);
    expect(loaded.logoBytes!.isNotEmpty, isTrue);

    await again.delete(created.id);
    expect(await again.loadById(created.id), isNull);
  });

  test('fromJson round-trip keeps fields', () {
    const original = CustomTicketTemplate(
      id: 't1',
      name: 'Demo',
      title: 'TITULO',
      companyName: 'MI TIENDA SAC',
      ruc: '20123456789',
      address: 'Av. Principal 123',
      lines: [
        CustomTicketLine(type: CustomTicketLineType.text, text: 'Hola'),
        CustomTicketLine(
          type: CustomTicketLineType.item,
          text: 'Item',
          qty: '1',
          unitPrice: '2',
          amount: '2',
        ),
      ],
      showTotals: true,
      currencySymbol: 'S/',
      subtotal: '2.00',
      total: '2.00',
      showQr: true,
      qrData: 'payload',
      showBarcode: false,
      footer: 'Pie',
      updatedAtMs: 123,
    );
    final restored = CustomTicketTemplate.fromJson(original.toJson());
    expect(restored.id, 't1');
    expect(restored.name, 'Demo');
    expect(restored.companyName, 'MI TIENDA SAC');
    expect(restored.ruc, '20123456789');
    expect(restored.address, 'Av. Principal 123');
    expect(restored.lines, hasLength(2));
    expect(restored.lines.last.isItem, isTrue);
    expect(restored.qrData, 'payload');
    expect(restored.footer, 'Pie');
  });

  test('escpos builder emits company header, totals, qr and barcode markers', () async {
    final ticket = CustomTicketTemplate(
      id: 't1',
      name: 'Demo',
      companyName: 'MI TIENDA',
      title: 'SHOULD NOT PRINT',
      lines: const [
        CustomTicketLine(
          type: CustomTicketLineType.item,
          text: 'PRODUCTO',
          qty: '1',
          unitPrice: '10.00',
          amount: '10.00',
        ),
      ],
      showTotals: true,
      subtotal: '10.00',
      tax: '1.80',
      total: '11.80',
      showQr: true,
      qrData: 'CUSTOM-QR-PAYLOAD',
      showBarcode: true,
      barcodeData: 'CODE128TEST',
      footer: 'Vuelva pronto',
    );
    final bytes = await CustomTicketEscPos.build(
      _printer(PaperWidth.mm80),
      ticket,
    );
    final text = _visible(bytes);
    expect(text, contains('MI TIENDA'));
    expect(text, isNot(contains('SHOULD NOT PRINT')));
    expect(text, contains('PRODUCTO'));
    expect(text, contains('TOTAL'));
    expect(text, contains('11.80'));
    expect(text, contains('Vuelva pronto'));
    // QR ESC/POS function marker GS ( k
    expect(_indexOf(bytes, [0x1D, 0x28, 0x6B]), greaterThan(0));
    // Barcode print GS k
    expect(_indexOf(bytes, [0x1D, 0x6B]), greaterThan(0));
  });

  test('escpos 58 mm without codes still prints free lines', () async {
    final ticket = const CustomTicketTemplate(
      id: 't2',
      name: 'Nota',
      title: '',
      lines: [
        CustomTicketLine(
          type: CustomTicketLineType.text,
          text: 'Solo texto',
          center: true,
          bold: true,
        ),
      ],
      showTotals: false,
      showQr: false,
      showBarcode: false,
    );
    final bytes = await CustomTicketEscPos.build(
      _printer(PaperWidth.mm58),
      ticket,
    );
    expect(_visible(bytes), contains('Solo texto'));
  });


  test('money parse and format normalize messy inputs', () {
    expect(CustomTicketMoney.parse('150.00'), 150.0);
    expect(CustomTicketMoney.parse('S/ 150.50'), 150.5);
    expect(CustomTicketMoney.parse('150,50'), 150.5);
    expect(CustomTicketMoney.format(150), '150.00');
    expect(CustomTicketMoney.withSymbol('S/', 150), 'S/ 150.00');
  });

  test('totals from lines: amounts without IGV', () {
    const lines = [
      CustomTicketLine(
        type: CustomTicketLineType.item,
        text: 'Cafe',
        qty: '2',
        unitPrice: '5.00',
        amount: '10.00',
      ),
      CustomTicketLine(
        type: CustomTicketLineType.item,
        text: 'Te',
        qty: '1',
        unitPrice: '3.00',
        amount: '3.00',
      ),
    ];
    final t = CustomTicketTotals.fromLines(lines);
    expect(t.subtotal, 13.0);
    expect(t.igv, closeTo(2.34, 0.001));
    expect(t.total, closeTo(15.34, 0.001));
  });

  test('preview uses columns for 32 and 48 cols', () {
    const ticket = CustomTicketTemplate(
      id: 't1',
      name: 'Demo',
      showTotals: true,
      lines: [
        CustomTicketLine(
          type: CustomTicketLineType.item,
          text: 'Producto nino',
          qty: '1',
          unitPrice: '10',
          amount: '10',
        ),
      ],
      subtotal: '10.00',
      tax: '1.80',
      total: '11.80',
    );
    final p32 = ticket.previewLines(cols: 32);
    expect(p32.any((l) => l.contains('Ct') && l.contains('P.U.')), isTrue);
    expect(p32.any((l) => l.contains('CtDESCRIPCION')), isFalse);
    expect(p32.any((l) => l.contains('Ct') && l.contains('DESCRIPCION')), isTrue);
    final header32 = p32.firstWhere((l) => l.contains('Ct'));
    expect(header32.contains('Ct '), isTrue);
    expect(p32.any((l) => l.contains('10.00')), isTrue);
    final moneyLine = p32.firstWhere((l) => l.contains('Producto'));
    // P.U. and IMP on same row as qty+desc (not a following-only money row)
    expect(moneyLine.contains('10.00'), isTrue);

    final p48 = ticket.previewLines(cols: 48);
    expect(p48.any((l) => l.contains('DESCRIPCION')), isTrue);
  });

  test('preview and escpos print company header under logo', () async {
    final ticket = CustomTicketTemplate(
      id: 'th',
      name: 'Demo',
      companyName: 'BODEGA CENTRAL',
      ruc: '20654321098',
      address: 'Jr. Lima 100',
      title: 'NOTA',
      lines: const [
        CustomTicketLine(
          type: CustomTicketLineType.item,
          text: 'Pan',
          qty: '1',
          unitPrice: '1',
          amount: '1',
        ),
      ],
      showTotals: true,
      subtotal: '1.00',
      tax: '0.18',
      total: '1.18',
    );
    final preview = ticket.previewLines(cols: 32);
    expect(preview.any((l) => l.contains('BODEGA CENTRAL')), isTrue);
    expect(preview.any((l) => l.contains('RUC: 20654321098')), isTrue);
    expect(preview.any((l) => l.contains('Jr. Lima 100')), isTrue);
    expect(preview.any((l) => l.contains('NOTA')), isFalse);

    final bytes = await CustomTicketEscPos.build(
      _printer(PaperWidth.mm58),
      ticket,
    );
    final text = _visible(bytes);
    expect(text, contains('BODEGA CENTRAL'));
    expect(text, contains('RUC: 20654321098'));
    expect(text, contains('Jr. Lima 100'));
    expect(text, isNot(contains('NOTA')));
    expect(text, contains('Ct'));
    expect(text.contains('CtDESCRIPCION'), isFalse);
  });

  test('escpos 58 mm prints item money on same row as columns', () async {
    final ticket = CustomTicketTemplate(
      id: 't58',
      name: 'Demo',
      title: 'TIENDA',
      lines: const [
        CustomTicketLine(
          type: CustomTicketLineType.item,
          text: 'CAFE NINO',
          qty: '2',
          unitPrice: '5.5',
          amount: '11',
        ),
      ],
      showTotals: true,
      subtotalLabel: 'Op. Gravada',
      subtotal: '11',
      taxLabel: 'IGV 18%',
      tax: '1.98',
      total: '12.98',
    );
    final bytes = await CustomTicketEscPos.build(
      _printer(PaperWidth.mm58),
      ticket,
    );
    final text = _visible(bytes);
    expect(text, contains('Ct'));
    expect(text, contains('P.U.'));
    expect(text, contains('5.50'));
    expect(text, contains('11.00'));
    expect(text, contains('S/ 11.00'));
    expect(text, contains('Op. Gravada'));
    expect(text, contains('IGV 18%'));
    // latin1-safe keeps printable ASCII product name
    expect(text, contains('CAFE'));
  });

}

SavedPrinter _printer(PaperWidth paper) {
  return SavedPrinter(
    id: 'p1',
    name: 'Caja',
    type: PrinterLinkType.bluetooth,
    address: 'AA:BB:CC:DD:EE:FF',
    paper: paper,
  );
}

Uint8List _pngSquare() {
  final image = img.Image(width: 40, height: 16, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(0, 0, 0));
  return Uint8List.fromList(img.encodePng(image));
}

String _visible(List<int> bytes) {
  final buf = StringBuffer();
  for (final b in bytes) {
    if (b >= 32 && b <= 126) {
      buf.writeCharCode(b);
    } else if (b == 10) {
      buf.write('\n');
    }
  }
  return buf.toString();
}

int _indexOf(List<int> hay, List<int> needle) {
  for (var i = 0; i <= hay.length - needle.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}