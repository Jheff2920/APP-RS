import 'package:flutter_test/flutter_test.dart';

import 'package:hello_world_app/services/sunat/sunat_ubl_parser.dart';

void main() {
  group('SunatUblParser', () {
    test('lee boleta 03 y arma el QR SUNAT', () {
      final t = SunatUblParser.parse(_boletaXml);
      expect(t.documentTypeCode, '03');
      expect(t.documentTypeLabel, 'BOLETA DE VENTA');
      expect(t.series, 'B001');
      expect(t.number, '00001234');
      expect(t.supplierRuc, '20123456789');
      expect(t.supplierName, 'LIMAFAC SAC');
      expect(t.customerDocType, '1');
      expect(t.customerDoc, '45678912');
      expect(t.customerName, 'JUAN PEREZ');
      expect(t.lines, hasLength(2));
      expect(t.lines.first.description, 'CAFE AMERICANO');
      expect(t.lines.first.quantity, 2);
      expect(t.igv, 3.24);
      expect(t.total, 21.24);
      expect(t.legend, contains('VEINTIUNO'));
      expect(
        t.qrPayload,
        '20123456789|03|B001|00001234|3.24|21.24|2026-09-08|1|45678912',
      );
    });

    test('lee factura 01', () {
      final t = SunatUblParser.parse(_facturaXml);
      expect(t.documentTypeCode, '01');
      expect(t.documentTypeLabel, 'FACTURA ELECTRONICA');
      expect(t.series, 'F001');
      expect(t.number, '55');
      expect(t.customerDocType, '6');
      expect(t.currency, 'PEN');
    });

    test('rechaza XML que no es Invoice', () {
      expect(
        () => SunatUblParser.parse('<CreditNote></CreditNote>'),
        throwsA(isA<SunatXmlException>()),
      );
    });

    test('rechaza tipo no soportado', () {
      expect(
        () => SunatUblParser.parse(_invoiceType('07')),
        throwsA(isA<SunatXmlException>()),
      );
    });
  });
}

const _boletaXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>B001-00001234</cbc:ID>
  <cbc:IssueDate>2026-09-08</cbc:IssueDate>
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
        <cac:RegistrationAddress>
          <cbc:StreetName>AV. EJEMPLO 123</cbc:StreetName>
          <cbc:CityName>LIMA</cbc:CityName>
        </cac:RegistrationAddress>
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
    <cac:Item>
      <cbc:Description>CAFE AMERICANO</cbc:Description>
    </cac:Item>
    <cac:Price>
      <cbc:PriceAmount currencyID="PEN">6.00</cbc:PriceAmount>
    </cac:Price>
  </cac:InvoiceLine>
  <cac:InvoiceLine>
    <cbc:InvoicedQuantity unitCode="NIU">1</cbc:InvoicedQuantity>
    <cbc:LineExtensionAmount currencyID="PEN">6.00</cbc:LineExtensionAmount>
    <cac:Item>
      <cbc:Description>PAN</cbc:Description>
    </cac:Item>
    <cac:Price>
      <cbc:PriceAmount currencyID="PEN">6.00</cbc:PriceAmount>
    </cac:Price>
  </cac:InvoiceLine>
</Invoice>
''';

const _facturaXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>F001-55</cbc:ID>
  <cbc:IssueDate>2026-01-15</cbc:IssueDate>
  <cbc:InvoiceTypeCode>01</cbc:InvoiceTypeCode>
  <cbc:DocumentCurrencyCode>PEN</cbc:DocumentCurrencyCode>
  <cac:AccountingSupplierParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="6">20999888777</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyName>
        <cbc:Name>DEMO EIRL</cbc:Name>
      </cac:PartyName>
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

String _invoiceType(String code) => '''
<Invoice xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>B001-1</cbc:ID>
  <cbc:InvoiceTypeCode>$code</cbc:InvoiceTypeCode>
</Invoice>
''';
