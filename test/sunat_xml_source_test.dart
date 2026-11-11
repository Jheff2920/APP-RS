import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_world_app/models/saved_printer.dart';
import 'package:hello_world_app/services/sunat/sunat_escpos_print.dart';
import 'package:hello_world_app/services/sunat/sunat_ubl_parser.dart';
import 'package:hello_world_app/services/sunat/sunat_xml_source.dart';

void main() {
  test('latin1Safe cambia comillas tipograficas del XML SUNAT', () {
    expect(
      SunatEscPosPrint.latin1Safe('4” X 3”'),
      '4" X 3"',
    );
    expect(SunatEscPosPrint.latin1Safe('Ñandú'), 'Ñandú');
  });

  test('lee XML CPE dentro de un ZIP SUNAT e ignora el CDR', () async {
    final xml = utf8Xml(_creditXml);
    final cdr = utf8Xml(
      '<ApplicationResponse><cbc:ID>R-FC02</cbc:ID></ApplicationResponse>',
    );
    final zip = Archive();
    zip.addFile(ArchiveFile('R-20123456789-07-FC02-00000137.xml', cdr.length, cdr));
    zip.addFile(ArchiveFile('20123456789-07-FC02-00000137.xml', xml.length, xml));
    final encoded = ZipEncoder().encode(zip);
    final file = File(
      '${Directory.systemTemp.path}/sunat_cpe_${DateTime.now().microsecondsSinceEpoch}.zip',
    );
    await file.writeAsBytes(encoded, flush: true);
    addTearDown(() => file.deleteSync());

    final parsed = SunatUblParser.parse(await SunatXmlSource.load(file.path));
    expect(parsed.documentTypeCode, '07');
    expect(parsed.series, 'FC02');
    expect(parsed.lines.first.description, contains('ROLLO'));
  });

  test('ZIP con demasiados archivos se rechaza sin descomprimirlo', () async {
    final zip = Archive();
    for (var i = 0; i < 60; i++) {
      final b = utf8Xml('<x/>');
      zip.addFile(ArchiveFile('f$i.xml', b.length, b));
    }
    final file = File(
      '${Directory.systemTemp.path}/sunat_many_${DateTime.now().microsecondsSinceEpoch}.zip',
    );
    await file.writeAsBytes(ZipEncoder().encode(zip), flush: true);
    addTearDown(() => file.deleteSync());
    await expectLater(
      SunatXmlSource.load(file.path),
      throwsA(isA<SunatXmlException>()),
    );
  });

  test('ZIP de factura SUNAT elige el Invoice y no el CDR', () async {
    final xml = utf8Xml(_facturaZipXml);
    final cdr = utf8Xml(
      '<ApplicationResponse><cbc:ID>R-F001</cbc:ID></ApplicationResponse>',
    );
    final zip = Archive();
    zip.addFile(ArchiveFile('R-20123456789-01-F001-00000001.xml', cdr.length, cdr));
    zip.addFile(ArchiveFile('20123456789-01-F001-00000001.xml', xml.length, xml));
    final file = File(
      '${Directory.systemTemp.path}/sunat_fac_${DateTime.now().microsecondsSinceEpoch}.zip',
    );
    await file.writeAsBytes(ZipEncoder().encode(zip), flush: true);
    addTearDown(() => file.deleteSync());

    final parsed = SunatUblParser.parse(await SunatXmlSource.load(file.path));
    expect(parsed.documentTypeCode, '01');
    expect(parsed.series, 'F001');
    expect(parsed.total, 118);
  });

  test('ZIP de guia de remision', () async {
    final xml = utf8Xml(_guiaZipXml);
    final zip = Archive();
    zip.addFile(ArchiveFile('20123456789-09-T001-00000021.xml', xml.length, xml));
    final file = File(
      '${Directory.systemTemp.path}/sunat_gre_${DateTime.now().microsecondsSinceEpoch}.zip',
    );
    await file.writeAsBytes(ZipEncoder().encode(zip), flush: true);
    addTearDown(() => file.deleteSync());

    final parsed = SunatUblParser.parse(await SunatXmlSource.load(file.path));
    expect(parsed.documentTypeCode, '09');
    expect(parsed.series, 'T001');
    expect(parsed.showTotals, isFalse);
  });

  test('XML declarado ISO-8859-1 respeta tildes/enie sin mojibake', () async {
    final xml = _isoXml(_isoCustomerName);
    final file = File(
      '${Directory.systemTemp.path}/sunat_iso_${DateTime.now().microsecondsSinceEpoch}.xml',
    );
    await file.writeAsBytes(xml, flush: true);
    addTearDown(() => file.deleteSync());

    final text = await SunatXmlSource.load(file.path);
    expect(text, contains('CERÁMICA'));
    expect(text, contains('SAN JUAN DE LURIGANCHO'));
    final parsed = SunatUblParser.parse(text);
    expect(parsed.supplierName, contains('CERÁMICA'));
  });

  test(
    'declarado ISO-8859-1 no se decodifica como UTF-8 aunque los bytes '
    'altos formen una secuencia UTF-8 valida por coincidencia',
    () async {
      // 0xC3 0xA9 en latin1 son dos caracteres sueltos ('Ã' '©'), pero esa
      // misma pareja de bytes es tambien la secuencia UTF-8 valida de 'é'.
      // Si decode() no respetara la declaracion del prolog y probara UTF-8
      // primero, este archivo pasaria sin lanzar excepcion y el nombre
      // quedaria corrupto en silencio.
      final prolog = latin1.encode(
        '<?xml version="1.0" encoding="ISO-8859-1"?>'
        '<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2">'
        '<cbc:ID xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">B01-1</cbc:ID>'
        '<cac:AccountingSupplierParty xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2">'
        '<cac:Party><cac:PartyLegalEntity><cbc:RegistrationName xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">',
      );
      final nameBytes = [0xC3, 0xA9]; // 'Ã©' en latin1
      final tail = latin1.encode(
        '</cbc:RegistrationName></cac:PartyLegalEntity></cac:Party>'
        '</cac:AccountingSupplierParty></Invoice>',
      );
      final bytes = [...prolog, ...nameBytes, ...tail];
      final file = File(
        '${Directory.systemTemp.path}/sunat_iso_coincidencia_${DateTime.now().microsecondsSinceEpoch}.xml',
      );
      await file.writeAsBytes(bytes, flush: true);
      addTearDown(() => file.deleteSync());

      final text = await SunatXmlSource.load(file.path);
      expect(text, contains('Ã©'));
      expect(text, isNot(contains('é')));
    },
  );

  test('arma ESC/POS de nota de credito con comillas unicode', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final ticket = SunatUblParser.parse(_creditXml);
    final bytes = await SunatEscPosPrint.build(_printer, ticket);
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(40));
  });
}

List<int> utf8Xml(String xml) => utf8.encode(xml);

List<int> _isoXml(String xml) => latin1.encode(xml);

final _printer = SavedPrinter(
  id: 't',
  name: 'test',
  type: PrinterLinkType.network,
  address: '127.0.0.1',
);

const _creditXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<CreditNote xmlns="urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2"
            xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
            xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>FC02-00000137</cbc:ID>
  <cbc:IssueDate>2026-09-08</cbc:IssueDate>
  <cbc:DocumentCurrencyCode>PEN</cbc:DocumentCurrencyCode>
  <cac:DiscrepancyResponse>
    <cbc:ReferenceID>F002-00005067</cbc:ReferenceID>
  </cac:DiscrepancyResponse>
  <cac:AccountingSupplierParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="6">20123456789</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>DEMO EMISOR SAC</cbc:RegistrationName>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingSupplierParty>
  <cac:AccountingCustomerParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="6">20612213888</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>CLIENTE SAC</cbc:RegistrationName>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingCustomerParty>
  <cac:TaxTotal>
    <cbc:TaxAmount>4.27</cbc:TaxAmount>
  </cac:TaxTotal>
  <cac:LegalMonetaryTotal>
    <cbc:PayableAmount>28.0</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>
  <cac:CreditNoteLine>
    <cbc:CreditedQuantity>1.0</cbc:CreditedQuantity>
    <cbc:LineExtensionAmount>23.73</cbc:LineExtensionAmount>
    <cac:Item>
      <cbc:Description>ROLLO 4” X 3”</cbc:Description>
    </cac:Item>
    <cac:Price>
      <cbc:PriceAmount>23.73</cbc:PriceAmount>
    </cac:Price>
  </cac:CreditNoteLine>
</CreditNote>
''';

const _facturaZipXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>F001-00000001</cbc:ID>
  <cbc:IssueDate>2026-09-09</cbc:IssueDate>
  <cbc:InvoiceTypeCode>01</cbc:InvoiceTypeCode>
  <cbc:DocumentCurrencyCode>PEN</cbc:DocumentCurrencyCode>
  <cac:AccountingSupplierParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="6">20123456789</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>DEMO EMISOR SAC</cbc:RegistrationName>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingSupplierParty>
  <cac:AccountingCustomerParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="6">20555666777</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>CLIENTE SAC</cbc:RegistrationName>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingCustomerParty>
  <cac:TaxTotal>
    <cbc:TaxAmount>18.00</cbc:TaxAmount>
  </cac:TaxTotal>
  <cac:LegalMonetaryTotal>
    <cbc:PayableAmount>118.00</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>
  <cac:InvoiceLine>
    <cbc:InvoicedQuantity>1</cbc:InvoicedQuantity>
    <cbc:LineExtensionAmount>100.00</cbc:LineExtensionAmount>
    <cac:Item>
      <cbc:Description>SERVICIO</cbc:Description>
    </cac:Item>
    <cac:Price>
      <cbc:PriceAmount>100.00</cbc:PriceAmount>
    </cac:Price>
  </cac:InvoiceLine>
</Invoice>
''';

const _guiaZipXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<DespatchAdvice xmlns="urn:oasis:names:specification:ubl:schema:xsd:DespatchAdvice-2"
                xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
                xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>T001-00000021</cbc:ID>
  <cbc:IssueDate>2026-09-09</cbc:IssueDate>
  <cbc:DespatchAdviceTypeCode>09</cbc:DespatchAdviceTypeCode>
  <cac:DespatchSupplierParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="6">20123456789</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>DEMO EMISOR SAC</cbc:RegistrationName>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:DespatchSupplierParty>
  <cac:DeliveryCustomerParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="6">20612213888</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>CLIENTE SAC</cbc:RegistrationName>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:DeliveryCustomerParty>
  <cac:DespatchLine>
    <cbc:DeliveredQuantity>3</cbc:DeliveredQuantity>
    <cac:Item>
      <cbc:Name>MERCADERIA</cbc:Name>
    </cac:Item>
  </cac:DespatchLine>
</DespatchAdvice>
''';

const _isoCustomerName = '''
<?xml version="1.0" encoding="ISO-8859-1" standalone="no"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>EB01-129</cbc:ID>
  <cbc:IssueDate>2026-11-04</cbc:IssueDate>
  <cbc:InvoiceTypeCode>03</cbc:InvoiceTypeCode>
  <cbc:DocumentCurrencyCode>PEN</cbc:DocumentCurrencyCode>
  <cac:AccountingSupplierParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="6">10407096547</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>CER\u00c1MICA C' CENTER</cbc:RegistrationName>
        <cac:RegistrationAddress>
          <cbc:District>SAN JUAN DE LURIGANCHO</cbc:District>
        </cac:RegistrationAddress>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingSupplierParty>
  <cac:AccountingCustomerParty>
    <cac:Party>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>COMERCIAL</cbc:RegistrationName>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingCustomerParty>
  <cac:LegalMonetaryTotal>
    <cbc:PayableAmount>2.36</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>
  <cac:InvoiceLine>
    <cbc:InvoicedQuantity>1</cbc:InvoicedQuantity>
    <cbc:LineExtensionAmount>2.0</cbc:LineExtensionAmount>
    <cac:Item>
      <cbc:Description>ABASTO</cbc:Description>
    </cac:Item>
    <cac:Price>
      <cbc:PriceAmount>2.00</cbc:PriceAmount>
    </cac:Price>
  </cac:InvoiceLine>
</Invoice>
''';
