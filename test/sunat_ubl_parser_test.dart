import 'dart:io';

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

    test('lee nota de credito 07 (UBL CreditNote de SUNAT)', () {
      final t = SunatUblParser.parse(_creditNoteXml);
      expect(t.documentTypeCode, '07');
      expect(t.documentTypeLabel, 'NOTA DE CREDITO ELECTRONICA');
      expect(t.series, 'FC02');
      expect(t.number, '00000137');
      expect(t.referenceId, 'F002-00005067');
      expect(t.supplierRuc, '20123456789');
      expect(t.supplierName, 'DEMO EMISOR SAC');
      expect(
        t.supplierAddress,
        'AV. INCA GARCILASO DE LA VEGA NRO. 1348 ---- CERCADO DE LIMA, Lima',
      );
      expect(t.customerDocType, '6');
      expect(t.customerDoc, '20612213888');
      expect(t.customerName, 'CLIENTE SAC');
      expect(t.lines, hasLength(1));
      expect(t.lines.first.quantity, 1);
      expect(t.lines.first.description, contains('ROLLO DE ETIQUETA TERMICA'));
      expect(t.lines.first.unitPrice, 23.73);
      expect(t.subtotal, 23.73);
      expect(t.igv, 4.27);
      expect(t.total, 28);
      expect(
        t.qrPayload,
        '20123456789|07|FC02|00000137|4.27|28.00|2026-09-08|6|20612213888',
      );
    });

    test('lee nota de debito 08', () {
      final t = SunatUblParser.parse(_debitNoteXml);
      expect(t.documentTypeCode, '08');
      expect(t.documentTypeLabel, 'NOTA DE DEBITO ELECTRONICA');
      expect(t.series, 'FD01');
      expect(t.referenceId, 'F001-10');
      expect(t.lines.first.quantity, 2);
      expect(t.total, 23.60);
    });

    test('lee guia de remision 09', () {
      final t = SunatUblParser.parse(_guiaXml);
      expect(t.documentTypeCode, '09');
      expect(t.documentTypeLabel, 'GUIA DE REMISION REMITENTE');
      expect(t.series, 'T001');
      expect(t.number, '00000021');
      expect(t.supplierRuc, '20123456789');
      expect(t.customerName, 'CLIENTE SAC');
      expect(t.referenceId, 'F001-55');
      expect(t.showTotals, isFalse);
      expect(t.lines, hasLength(1));
      expect(t.lines.first.quantity, 10);
      expect(t.lines.first.description, 'CAJAS DE PAPEL');
      expect(t.details, contains('Motivo: Venta'));
      expect(t.details, contains('Placa: ABC-123'));
      expect(t.details.any((d) => d.contains('AV. PARTIDA')), isTrue);
      expect(t.details.any((d) => d.contains('AV. LLEGADA')), isTrue);
    });

    test('lee liquidacion de compra 04', () {
      final t = SunatUblParser.parse(_invoiceType('04'));
      expect(t.documentTypeCode, '04');
      expect(t.documentTypeLabel, 'LIQUIDACION DE COMPRA');
    });

    test('rechaza XML que no es comprobante UBL', () {
      expect(
        () => SunatUblParser.parse('<VoidedDocuments></VoidedDocuments>'),
        throwsA(isA<SunatXmlException>()),
      );
    });

    test('rechaza Invoice con tipo 07 (debe ser CreditNote)', () {
      expect(
        () => SunatUblParser.parse(_invoiceType('07')),
        throwsA(isA<SunatXmlException>()),
      );
    });

    test('parsea el XML CreditNote bajado de SUNAT', () {
      const path =
          r'C:\Users\RS-Soporte\Downloads\20563358549-07-FC02-00000137.xml';
      final file = File(path);
      if (!file.existsSync()) {
        markTestSkipped('XML SUNAT no esta en Downloads');
        return;
      }
      final t = SunatUblParser.parse(file.readAsStringSync());
      expect(t.documentTypeCode, '07');
      expect(t.documentId, 'FC02-00000137');
      expect(t.referenceId, 'F002-00005067');
      expect(t.supplierRuc, '20563358549');
      expect(t.customerDoc, '20612213888');
      expect(t.supplierAddress, contains('INCA GARCILASO'));
      expect(t.supplierAddress.toUpperCase(), isNot(contains('NONE')));
      expect(t.lines, hasLength(1));
      expect(t.lines.first.quantity, 1);
      expect(t.total, 28);
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

const _creditNoteXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<CreditNote xmlns="urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2"
            xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
            xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>FC02-00000137</cbc:ID>
  <cbc:IssueDate>2026-09-08</cbc:IssueDate>
  <cbc:DocumentCurrencyCode>PEN</cbc:DocumentCurrencyCode>
  <cac:DiscrepancyResponse>
    <cbc:ReferenceID>F002-00005067</cbc:ReferenceID>
    <cbc:ResponseCode>06</cbc:ResponseCode>
  </cac:DiscrepancyResponse>
  <cac:BillingReference>
    <cac:InvoiceDocumentReference>
      <cbc:ID>F002-00005067</cbc:ID>
      <cbc:DocumentTypeCode>01</cbc:DocumentTypeCode>
    </cac:InvoiceDocumentReference>
  </cac:BillingReference>
  <cac:AccountingSupplierParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="6">20123456789</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyName>
        <cbc:Name><![CDATA[DEMO EMISOR SAC]]></cbc:Name>
      </cac:PartyName>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName><![CDATA[DEMO EMISOR SAC]]></cbc:RegistrationName>
        <cac:RegistrationAddress>
          <cbc:CitySubdivisionName>NONE</cbc:CitySubdivisionName>
          <cbc:CityName>Lima</cbc:CityName>
          <cbc:CountrySubentity>Lima</cbc:CountrySubentity>
          <cbc:District>Lima</cbc:District>
          <cac:AddressLine>
            <cbc:Line><![CDATA[AV. INCA GARCILASO DE LA VEGA NRO. 1348 ---- CERCADO DE LIMA]]></cbc:Line>
          </cac:AddressLine>
        </cac:RegistrationAddress>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingSupplierParty>
  <cac:AccountingCustomerParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="6">20612213888</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName><![CDATA[CLIENTE SAC]]></cbc:RegistrationName>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingCustomerParty>
  <cac:TaxTotal>
    <cbc:TaxAmount currencyID="PEN">4.27</cbc:TaxAmount>
  </cac:TaxTotal>
  <cac:LegalMonetaryTotal>
    <cbc:LineExtensionAmount currencyID="PEN">23.73</cbc:LineExtensionAmount>
    <cbc:PayableAmount currencyID="PEN">28.0</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>
  <cac:CreditNoteLine>
    <cbc:CreditedQuantity unitCode="NIU">1.0</cbc:CreditedQuantity>
    <cbc:LineExtensionAmount currencyID="PEN">23.73</cbc:LineExtensionAmount>
    <cac:Item>
      <cbc:Description><![CDATA[[SUMR100052] ROLLO DE ETIQUETA TERMICA T.D. DE 4” X 3” RX750 A 1 COLUMNAS]]></cbc:Description>
    </cac:Item>
    <cac:Price>
      <cbc:PriceAmount currencyID="PEN">23.7300000000</cbc:PriceAmount>
    </cac:Price>
  </cac:CreditNoteLine>
</CreditNote>
''';

const _debitNoteXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<DebitNote xmlns="urn:oasis:names:specification:ubl:schema:xsd:DebitNote-2"
           xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
           xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>FD01-00000008</cbc:ID>
  <cbc:IssueDate>2026-09-08</cbc:IssueDate>
  <cbc:DocumentCurrencyCode>PEN</cbc:DocumentCurrencyCode>
  <cac:DiscrepancyResponse>
    <cbc:ReferenceID>F001-10</cbc:ReferenceID>
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
        <cbc:ID schemeID="6">20555666777</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>CLIENTE SAC</cbc:RegistrationName>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingCustomerParty>
  <cac:TaxTotal>
    <cbc:TaxAmount>3.60</cbc:TaxAmount>
  </cac:TaxTotal>
  <cac:LegalMonetaryTotal>
    <cbc:PayableAmount>23.60</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>
  <cac:DebitNoteLine>
    <cbc:DebitedQuantity>2</cbc:DebitedQuantity>
    <cbc:LineExtensionAmount>20.00</cbc:LineExtensionAmount>
    <cac:Item>
      <cbc:Description>AJUSTE</cbc:Description>
    </cac:Item>
    <cac:Price>
      <cbc:PriceAmount>10.00</cbc:PriceAmount>
    </cac:Price>
  </cac:DebitNoteLine>
</DebitNote>
''';

const _guiaXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<DespatchAdvice xmlns="urn:oasis:names:specification:ubl:schema:xsd:DespatchAdvice-2"
                xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
                xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>T001-00000021</cbc:ID>
  <cbc:IssueDate>2026-09-09</cbc:IssueDate>
  <cbc:DespatchAdviceTypeCode>09</cbc:DespatchAdviceTypeCode>
  <cac:AdditionalDocumentReference>
    <cbc:ID>F001-55</cbc:ID>
    <cbc:DocumentTypeCode>01</cbc:DocumentTypeCode>
  </cac:AdditionalDocumentReference>
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
  <cac:Shipment>
    <cbc:HandlingCode>01</cbc:HandlingCode>
    <cbc:GrossWeightMeasure unitCode="KGM">12.5</cbc:GrossWeightMeasure>
    <cac:ShipmentStage>
      <cac:TransportMeans>
        <cac:RoadTransport>
          <cbc:LicensePlateID>ABC-123</cbc:LicensePlateID>
        </cac:RoadTransport>
      </cac:TransportMeans>
    </cac:ShipmentStage>
    <cac:Delivery>
      <cac:DeliveryAddress>
        <cbc:StreetName>AV. LLEGADA 100</cbc:StreetName>
        <cbc:CityName>Lima</cbc:CityName>
      </cac:DeliveryAddress>
    </cac:Delivery>
    <cac:OriginAddress>
      <cbc:StreetName>AV. PARTIDA 200</cbc:StreetName>
      <cbc:CityName>Lima</cbc:CityName>
    </cac:OriginAddress>
  </cac:Shipment>
  <cac:DespatchLine>
    <cbc:DeliveredQuantity unitCode="NIU">10</cbc:DeliveredQuantity>
    <cac:Item>
      <cbc:Name>CAJAS DE PAPEL</cbc:Name>
    </cac:Item>
  </cac:DespatchLine>
</DespatchAdvice>
''';
