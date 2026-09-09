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

  test('arma ESC/POS de nota de credito con comillas unicode', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final ticket = SunatUblParser.parse(_creditXml);
    final bytes = await SunatEscPosPrint.build(_printer, ticket);
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(40));
  });
}

List<int> utf8Xml(String xml) => utf8.encode(xml);

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
