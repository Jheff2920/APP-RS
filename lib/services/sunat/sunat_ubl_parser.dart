import 'package:xml/xml.dart';

import 'sunat_ticket.dart';

class SunatXmlException implements Exception {
  SunatXmlException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Parser UBL 2.1 de SUNAT (Invoice boleta 03 / factura 01).
class SunatUblParser {
  static const supportedTypes = {'01', '03'};

  static SunatTicket parse(String xmlSource) {
    final source = xmlSource.replaceFirst('\uFEFF', '').trim();
    if (source.isEmpty) {
      throw SunatXmlException('El XML esta vacio.');
    }

    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(source);
    } on XmlException {
      throw SunatXmlException('El archivo no es un XML valido.');
    }

    final root = doc.rootElement;
    if (root.localName != 'Invoice') {
      throw SunatXmlException(
        'Este XML no es una boleta/factura UBL de SUNAT '
        '(se esperaba Invoice, llego ${root.localName}).',
      );
    }

    final type = _digits(_directText(root, 'InvoiceTypeCode'));
    if (!supportedTypes.contains(type)) {
      throw SunatXmlException(
        'Solo se imprimen boletas (03) y facturas (01). '
        'Este comprobante es tipo ${type.isEmpty ? "?" : type}.',
      );
    }

    final id = _directText(root, 'ID');
    final parts = _splitId(id);
    final supplier = _find(root, 'AccountingSupplierParty');
    final customer = _find(root, 'AccountingCustomerParty');
    final legal = _find(root, 'LegalMonetaryTotal');
    final taxTotal = _find(root, 'TaxTotal');

    final supplierId = _find(supplier, 'PartyIdentification');
    final customerId = _find(customer, 'PartyIdentification');

    final subtotal = _num(
      _text(legal, 'LineExtensionAmount'),
      fallback: _num(_text(legal, 'TaxExclusiveAmount')),
    );
    final total = _num(
      _text(legal, 'PayableAmount'),
      fallback: _num(_text(legal, 'TaxInclusiveAmount')),
    );
    final igv = _num(_text(taxTotal, 'TaxAmount'));

    return SunatTicket(
      documentTypeCode: type,
      series: parts.$1,
      number: parts.$2,
      issueDate: _directText(root, 'IssueDate'),
      currency: _directText(root, 'DocumentCurrencyCode').ifEmpty('PEN'),
      supplierRuc: _text(supplierId, 'ID'),
      supplierName: _firstNonEmpty([
        _text(supplier, 'RegistrationName'),
        _text(supplier, 'Name'),
      ]),
      supplierAddress: _address(supplier),
      customerDocType: _attr(_find(customerId, 'ID'), 'schemeID'),
      customerDoc: _text(customerId, 'ID'),
      customerName: _firstNonEmpty([
        _text(customer, 'RegistrationName'),
        _text(customer, 'Name'),
      ]),
      lines: _lines(root),
      subtotal: subtotal,
      igv: igv,
      total: total,
      legend: _legend(root),
    );
  }

  static List<SunatLine> _lines(XmlElement root) {
    final out = <SunatLine>[];
    for (final line in root.childElements.where((e) => e.localName == 'InvoiceLine')) {
      final qty = _num(_text(line, 'InvoicedQuantity'), fallback: 1);
      final amount = _num(_text(line, 'LineExtensionAmount'));
      final price = _num(
        _text(_find(line, 'Price'), 'PriceAmount'),
        fallback: qty == 0 ? amount : amount / qty,
      );
      final desc = _firstNonEmpty([
        _text(line, 'Description'),
        _text(line, 'Name'),
      ]);
      out.add(
        SunatLine(
          quantity: qty,
          description: desc.ifEmpty('Item'),
          unitPrice: price,
          amount: amount,
        ),
      );
    }
    return out;
  }

  static String _legend(XmlElement root) {
    for (final note in root.childElements.where((e) => e.localName == 'Note')) {
      final id = note.getAttribute('languageLocaleID') ?? '';
      if (id == '1000' || id == '1002') {
        final t = note.innerText.trim();
        if (t.isNotEmpty) return t;
      }
    }
    for (final note in root.childElements.where((e) => e.localName == 'Note')) {
      final t = note.innerText.trim();
      if (t.isNotEmpty && t.length > 8) return t;
    }
    return '';
  }

  static String _address(XmlElement? party) {
    final addr = _find(party, 'RegistrationAddress') ??
        _find(party, 'PostalAddress');
    if (addr == null) return '';
    return [
      _text(addr, 'StreetName'),
      _text(addr, 'CitySubdivisionName'),
      _text(addr, 'CityName'),
      _text(addr, 'CountrySubentity'),
    ].where((s) => s.isNotEmpty).join(', ');
  }

  static (String, String) _splitId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return ('', '');
    final i = trimmed.indexOf('-');
    if (i <= 0 || i >= trimmed.length - 1) return (trimmed, '');
    return (trimmed.substring(0, i), trimmed.substring(i + 1));
  }

  static XmlElement? _find(XmlNode? scope, String local) {
    if (scope == null) return null;
    return scope.descendants
        .whereType<XmlElement>()
        .where((e) => e.localName == local)
        .firstOrNull;
  }

  static String _directText(XmlElement parent, String local) {
    return parent.childElements
            .where((e) => e.localName == local)
            .firstOrNull
            ?.innerText
            .trim() ??
        '';
  }

  static String _text(XmlNode? scope, String local) {
    return _find(scope, local)?.innerText.trim() ?? '';
  }

  static String _attr(XmlElement? el, String name) {
    return el?.getAttribute(name)?.trim() ?? '';
  }

  static String _digits(String raw) {
    final m = RegExp(r'\d+').firstMatch(raw.trim());
    return m?.group(0) ?? raw.trim();
  }

  static double _num(String raw, {double fallback = 0}) {
    final n = double.tryParse(raw.replaceAll(',', '').trim());
    return n ?? fallback;
  }

  static String _firstNonEmpty(List<String> values) {
    for (final v in values) {
      if (v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
