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
  });

  /// `01` factura, `03` boleta.
  final String documentTypeCode;
  final String series;
  final String number;
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

  String get documentTypeLabel {
    switch (documentTypeCode) {
      case '01':
        return 'FACTURA ELECTRONICA';
      case '03':
        return 'BOLETA DE VENTA';
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
