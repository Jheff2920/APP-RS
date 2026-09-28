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
    expect(restored.lines, hasLength(2));
    expect(restored.lines.last.isItem, isTrue);
    expect(restored.qrData, 'payload');
    expect(restored.footer, 'Pie');
  });

  test('escpos builder emits title, totals, qr and barcode markers', () async {
    final ticket = CustomTicketTemplate(
      id: 't1',
      name: 'Demo',
      title: 'MI TIENDA',
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