import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:hello_world_app/models/paper_width.dart';
import 'package:hello_world_app/models/saved_printer.dart';
import 'package:hello_world_app/services/sunat/sunat_escpos_print.dart';
import 'package:hello_world_app/services/sunat/sunat_print_settings.dart';
import 'package:hello_world_app/services/sunat/sunat_ticket.dart';
import 'package:hello_world_app/services/sunat/sunat_ubl_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('claro layout prints sections, note, and QR caption', () async {
    final bytes = await SunatEscPosPrint.build(
      _printer(PaperWidth.mm80),
      SunatUblParser.parse(_boleta),
      settings: const SunatPrintSettings(
        format: SunatTicketFormat.claro,
        footerNote: 'Mesa 4',
      ),
    );
    final text = _visible(bytes);
    expect(text, contains('LIMAFAC SAC'));
    expect(text, contains('B001-00001234'));
    expect(text, contains('CLIENTE'));
    expect(text, contains('P.U.'));
    expect(text, contains('Consulte en SUNAT'));
    expect(text, contains('Gracias por su compra'));
    expect(text, contains('Mesa 4'));
    expect(_indexOf(bytes, [0x1D, 0x76, 0x30]), greaterThan(_indexOfText(bytes, 'LIMAFAC')));
  });

  test('58 mm and detallado include the unit and customer address', () async {
    final bytes = await SunatEscPosPrint.build(
      _printer(PaperWidth.mm58),
      SunatUblParser.parse(_boleta),
      settings: const SunatPrintSettings(format: SunatTicketFormat.detallado),
    );
    final text = _visible(bytes);
    expect(text, contains('B001-00001234'));
    expect(text, contains('UND'));
    expect(text, contains('AV. CLIENTE 456'));
    expect(text, contains('14:05'));
    expect(text, contains('Moneda: PEN'));
    expect(text, isNot(contains('P.U.')));
  });

  test('logo raster is centered above the company name', () async {
    final logo = _pngSquare();
    final withLogo = await SunatEscPosPrint.build(
      _printer(PaperWidth.mm58),
      _ticket(),
      settings: const SunatPrintSettings(showQr: false),
      logoBytes: logo,
    );
    final plain = await SunatEscPosPrint.build(
      _printer(PaperWidth.mm58),
      _ticket(),
      settings: const SunatPrintSettings(showQr: false),
    );
    final nameAt = _indexOfText(withLogo, 'LIMAFAC');
    expect(nameAt, greaterThan(0));
    expect(_indexOf(withLogo, [0x1D, 0x76, 0x30]), lessThan(nameAt));
    expect(_indexOf(plain, [0x1D, 0x76, 0x30]), greaterThan(_indexOfText(plain, 'LIMAFAC')));
    expect(withLogo.length, greaterThan(plain.length));
  });

  test('compact keeps the short customer line and can hide the legend', () async {
    final bytes = await SunatEscPosPrint.build(
      _printer(PaperWidth.mm80),
      _ticket(),
      settings: const SunatPrintSettings(
        format: SunatTicketFormat.compacto,
        showLegend: false,
        showQr: false,
      ),
    );
    final text = _visible(bytes);
    expect(text, contains('Cliente: JUAN PEREZ'));
    expect(text, isNot(contains('\nCLIENTE')));
    expect(text, contains('Gracias'));
    expect(text, isNot(contains('VEINTIUNO')));
    expect(text, isNot(contains('Consulte en SUNAT')));
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

SunatTicket _ticket() {
  return const SunatTicket(
    documentTypeCode: '03',
    series: 'B001',
    number: '00001234',
    issueDate: '2026-09-08',
    currency: 'PEN',
    supplierRuc: '20123456789',
    supplierName: 'LIMAFAC SAC',
    supplierAddress: 'AV. EJEMPLO 123',
    customerDocType: '1',
    customerDoc: '45678912',
    customerName: 'JUAN PEREZ',
    lines: [
      SunatLine(
        quantity: 2,
        description: 'CAFE AMERICANO',
        unitPrice: 6,
        amount: 12,
        unit: 'NIU',
      ),
    ],
    subtotal: 18,
    igv: 3.24,
    total: 21.24,
    legend: 'SON VEINTIUNO CON 24/100 SOLES',
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

int _indexOfText(List<int> bytes, String text) {
  return _indexOf(bytes, text.codeUnits);
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
  <cbc:Note languageLocaleID="1000">SON VEINTIUNO CON 24/100 SOLES</cbc:Note>
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
        <cac:RegistrationAddress>
          <cbc:StreetName>AV. CLIENTE 456</cbc:StreetName>
          <cbc:CityName>LIMA</cbc:CityName>
        </cac:RegistrationAddress>
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
''';
