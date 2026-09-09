import 'package:xml/xml.dart';

import 'sunat_ticket.dart';

class SunatXmlException implements Exception {
  SunatXmlException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Parser UBL 2.1 / SUNAT de los XML que vienen en el ZIP CPE.
class SunatUblParser {
  static const _rejectRoots = {
    'ApplicationResponse',
    'VoidedDocuments',
    'SummaryDocuments',
  };

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
    if (_rejectRoots.contains(root.localName)) {
      throw SunatXmlException(
        'Este XML no es un comprobante imprimible '
        '(${root.localName}: es CDR o resumen SUNAT).',
      );
    }

    final type = _documentType(root);
    final id = _directText(root, 'ID');
    if (id.isEmpty) {
      throw SunatXmlException('El XML no tiene serie-numero (cbc:ID).');
    }
    final parts = _splitId(id);

    final supplier = _find(root, 'AccountingSupplierParty') ??
        _find(root, 'DespatchSupplierParty') ??
        _find(root, 'AgentParty');
    final customer = _find(root, 'AccountingCustomerParty') ??
        _find(root, 'DeliveryCustomerParty') ??
        _find(root, 'ReceiverParty');
    final legal = _find(root, 'LegalMonetaryTotal');
    final taxTotal = _find(root, 'TaxTotal');

    final supplierId = _find(supplier, 'PartyIdentification');
    final customerId = _find(customer, 'PartyIdentification');

    final subtotal = _num(
      _text(legal, 'LineExtensionAmount'),
      fallback: _num(_text(legal, 'TaxExclusiveAmount')),
    );
    var total = _num(
      _text(legal, 'PayableAmount'),
      fallback: _num(_text(legal, 'TaxInclusiveAmount')),
    );
    if (total == 0) {
      total = _num(_directText(root, 'TotalInvoiceAmount'));
    }
    final igv = _num(_text(taxTotal, 'TaxAmount'));
    final showTotals = type != '09' && type != '31';

    return SunatTicket(
      documentTypeCode: type,
      series: parts.$1,
      number: parts.$2,
      issueDate: _directText(root, 'IssueDate'),
      currency: _directText(root, 'DocumentCurrencyCode').ifEmpty('PEN'),
      supplierRuc: _firstNonEmpty([
        _text(supplierId, 'ID'),
        _text(supplier, 'CustomerAssignedAccountID'),
        _text(supplier, 'CompanyID'),
      ]),
      supplierName: _firstNonEmpty([
        _text(supplier, 'RegistrationName'),
        _text(supplier, 'Name'),
      ]),
      supplierAddress: _address(supplier),
      customerDocType: _firstNonEmpty([
        _attr(_find(customerId, 'ID'), 'schemeID'),
        _attr(_find(customer, 'CustomerAssignedAccountID'), 'schemeID'),
      ]),
      customerDoc: _firstNonEmpty([
        _text(customerId, 'ID'),
        _text(customer, 'CustomerAssignedAccountID'),
      ]),
      customerName: _firstNonEmpty([
        _text(customer, 'RegistrationName'),
        _text(customer, 'Name'),
      ]),
      lines: _lines(root),
      subtotal: subtotal,
      igv: igv,
      total: total,
      legend: _legend(root),
      referenceId: _referenceId(root),
      details: _details(root, type),
      showTotals: showTotals,
    );
  }

  static String _documentType(XmlElement root) {
    switch (root.localName) {
      case 'Invoice':
      case 'SelfBilledInvoice':
        final type = _digits(_directText(root, 'InvoiceTypeCode'));
        if (type == '07' || type == '08') {
          throw SunatXmlException(
            'La nota ${type == '07' ? 'de credito' : 'de debito'} '
            'debe venir como CreditNote/DebitNote, no como Invoice.',
          );
        }
        if (type.isNotEmpty) return type;
        return _typeFromSeries(_directText(root, 'ID'), '01');
      case 'CreditNote':
        return _digits(_directText(root, 'CreditNoteTypeCode')).ifEmpty('07');
      case 'DebitNote':
        return _digits(_directText(root, 'DebitNoteTypeCode')).ifEmpty('08');
      case 'DespatchAdvice':
        return _digits(_directText(root, 'DespatchAdviceTypeCode'))
            .ifEmpty(_typeFromSeries(_directText(root, 'ID'), '09'));
      case 'Retention':
        return '20';
      case 'Perception':
        return '40';
      default:
        throw SunatXmlException(
          'Este XML no es un comprobante UBL de SUNAT '
          '(llego ${root.localName}).',
        );
    }
  }

  static String _typeFromSeries(String id, String fallback) {
    final series = _splitId(id).$1.toUpperCase();
    if (series.startsWith('B')) return '03';
    if (series.startsWith('F')) return '01';
    if (series.startsWith('T')) return '09';
    if (series.startsWith('V')) return '31';
    if (series.startsWith('R')) return '20';
    if (series.startsWith('P')) return '40';
    return fallback;
  }

  static String _referenceId(XmlElement root) {
    final discrepancy = _find(root, 'DiscrepancyResponse');
    return _firstNonEmpty([
      if (discrepancy != null) _directText(discrepancy, 'ReferenceID'),
      _text(_find(root, 'InvoiceDocumentReference'), 'ID'),
      _text(_find(root, 'AdditionalDocumentReference'), 'ID'),
      _text(_find(root, 'OrderReference'), 'ID'),
    ]);
  }

  static const _lineTags = {
    'InvoiceLine',
    'CreditNoteLine',
    'DebitNoteLine',
    'DespatchLine',
    'SUNATRetentionDocumentReference',
    'SUNATPerceptionDocumentReference',
  };

  static List<SunatLine> _lines(XmlElement root) {
    final out = <SunatLine>[];
    for (final line in root.childElements.where((e) => _lineTags.contains(e.localName))) {
      final qty = _num(
        _firstNonEmpty([
          _directText(line, 'InvoicedQuantity'),
          _directText(line, 'CreditedQuantity'),
          _directText(line, 'DebitedQuantity'),
          _directText(line, 'DeliveredQuantity'),
        ]),
        fallback: 1,
      );
      final amount = _num(
        _directText(line, 'LineExtensionAmount'),
        fallback: _num(
          _firstNonEmpty([
            _text(line, 'SUNATRetentionAmount'),
            _text(line, 'SUNATPerceptionAmount'),
            _directText(line, 'TotalInvoiceAmount'),
          ]),
        ),
      );
      final price = _num(
        _text(_find(line, 'Price'), 'PriceAmount'),
        fallback: qty == 0 ? amount : amount / qty,
      );
      final desc = _firstNonEmpty([
        _text(line, 'Description'),
        _text(_find(line, 'Item'), 'Name'),
        if (_directText(line, 'ID').contains('-')) 'Doc. ${_directText(line, 'ID')}',
      ]);
      out.add(
        SunatLine(
          quantity: qty,
          description: desc.ifEmpty('Item'),
          unitPrice: price.isFinite ? price : 0,
          amount: amount,
        ),
      );
    }
    return out;
  }

  static List<String> _details(XmlElement root, String type) {
    if (type != '09' && type != '31') return const [];
    final shipment = _find(root, 'Shipment');
    if (shipment == null) return const [];
    final motivo = _motivo(_text(shipment, 'HandlingCode'));
    final info = _firstNonEmpty([
      _text(shipment, 'Information'),
      _text(shipment, 'HandlingInstructions'),
    ]);
    final weightEl = _find(shipment, 'GrossWeightMeasure');
    final weight = (weightEl?.innerText.trim() ?? '').ifEmpty('');
    final weightUnit = _attr(weightEl, 'unitCode');
    final placa = _text(shipment, 'LicensePlateID');
    final origin = _addressNode(_find(shipment, 'OriginAddress'));
    final dest = _addressNode(
      _find(shipment, 'DeliveryAddress') ??
          _find(_find(shipment, 'Delivery'), 'Address'),
    );
    return [
      if (motivo.isNotEmpty) 'Motivo: $motivo',
      if (info.isNotEmpty) info,
      if (weight.isNotEmpty)
        'Peso: $weight${weightUnit.isEmpty ? '' : ' $weightUnit'}',
      if (placa.isNotEmpty) 'Placa: $placa',
      if (origin.isNotEmpty) 'Partida: $origin',
      if (dest.isNotEmpty) 'Llegada: $dest',
    ];
  }

  static String _motivo(String code) {
    switch (code) {
      case '01':
        return 'Venta';
      case '02':
        return 'Compra';
      case '04':
        return 'Traslado entre establecimientos';
      case '08':
        return 'Importacion';
      case '09':
        return 'Exportacion';
      case '13':
        return 'Otros';
      case '14':
        return 'Venta sujeta a confirmar';
      case '18':
        return 'Traslado emisor itinerante CP';
      case '19':
        return 'Traslado a zona primaria';
      default:
        return code;
    }
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
    return _addressNode(
      _find(party, 'RegistrationAddress') ?? _find(party, 'PostalAddress'),
    );
  }

  static String _addressNode(XmlElement? addr) {
    if (addr == null) return '';
    final parts = <String>[];
    for (final raw in [
      _text(addr, 'StreetName'),
      _text(addr, 'Line'),
      _text(addr, 'CitySubdivisionName'),
      _text(addr, 'CityName'),
      _text(addr, 'District'),
      _text(addr, 'CountrySubentity'),
    ]) {
      final s = raw.trim();
      if (s.isEmpty) continue;
      if (s.toUpperCase() == 'NONE' || s == '-') continue;
      if (parts.any((p) => p.toLowerCase() == s.toLowerCase())) continue;
      parts.add(s);
    }
    return parts.join(', ');
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
