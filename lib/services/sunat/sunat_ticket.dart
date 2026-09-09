class SunatLine {
  const SunatLine({
    required this.quantity,
    required this.description,
    required this.unitPrice,
    required this.amount,
  });

  final double quantity;
  final String description;
  final double unitPrice;
  final double amount;
}

class SunatTicket {
  const SunatTicket({
    required this.documentTypeCode,
    required this.series,
    required this.number,
    required this.issueDate,
    required this.currency,
    required this.supplierRuc,
    required this.supplierName,
    required this.supplierAddress,
    required this.customerDocType,
    required this.customerDoc,
    required this.customerName,
    required this.lines,
    required this.subtotal,
    required this.igv,
    required this.total,
    required this.legend,
    this.referenceId = '',
    this.details = const [],
    this.showTotals = true,
  });

  /// Catalogo 01: 01 factura, 03 boleta, 07 NC, 08 ND, 09/31 guia, 20 retencion, 40 percepcion.
  final String documentTypeCode;
  final String series;
  final String number;
  /// Comprobante afectado o relacionado (NC/ND/guia).
  final String referenceId;
  final String issueDate;
  final String currency;
  final String supplierRuc;
  final String supplierName;
  final String supplierAddress;
  final String customerDocType;
  final String customerDoc;
  final String customerName;
  final List<SunatLine> lines;
  final double subtotal;
  final double igv;
  final double total;
  final String legend;
  /// Extra de guia/retencion (motivo, placa, partida, llegada).
  final List<String> details;
  final bool showTotals;

  bool get isDespatch =>
      documentTypeCode == '09' || documentTypeCode == '31';

  String get documentTypeLabel {
    switch (documentTypeCode) {
      case '01':
        return 'FACTURA ELECTRONICA';
      case '03':
        return 'BOLETA DE VENTA';
      case '04':
        return 'LIQUIDACION DE COMPRA';
      case '07':
        return 'NOTA DE CREDITO ELECTRONICA';
      case '08':
        return 'NOTA DE DEBITO ELECTRONICA';
      case '09':
        return 'GUIA DE REMISION REMITENTE';
      case '20':
        return 'COMPROBANTE DE RETENCION';
      case '31':
        return 'GUIA DE REMISION TRANSPORTISTA';
      case '40':
        return 'COMPROBANTE DE PERCEPCION';
      default:
        return 'COMPROBANTE $documentTypeCode';
    }
  }

  String get documentId {
    if (series.isEmpty) return number;
    if (number.isEmpty) return series;
    return '$series-$number';
  }

  String get currencySymbol =>
      currency.toUpperCase() == 'USD' ? 'USD' : 'S/';

  /// Payload QR SUNAT (RUC|tipo|serie|numero|IGV|total|fecha|tipoDoc|numDoc).
  String get qrPayload {
    return [
      supplierRuc,
      documentTypeCode,
      series,
      number,
      _money(igv),
      _money(total),
      issueDate,
      customerDocType,
      customerDoc,
    ].join('|');
  }

  static String _money(double n) => n.toStringAsFixed(2);
}
