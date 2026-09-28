import 'dart:convert';
import 'dart:typed_data';

/// Tipo de línea en un ticket propio.
enum CustomTicketLineType {
  text,
  item;

  static CustomTicketLineType fromName(String? raw) {
    for (final v in CustomTicketLineType.values) {
      if (v.name == raw) return v;
    }
    return CustomTicketLineType.text;
  }
}

/// Línea libre o ítem (cantidad / descripción / precios).
class CustomTicketLine {
  const CustomTicketLine({
    this.type = CustomTicketLineType.text,
    this.text = '',
    this.bold = false,
    this.center = false,
    this.qty = '',
    this.unitPrice = '',
    this.amount = '',
  });

  final CustomTicketLineType type;
  final String text;
  final bool bold;
  final bool center;
  final String qty;
  final String unitPrice;
  final String amount;

  bool get isItem => type == CustomTicketLineType.item;

  CustomTicketLine copyWith({
    CustomTicketLineType? type,
    String? text,
    bool? bold,
    bool? center,
    String? qty,
    String? unitPrice,
    String? amount,
  }) {
    return CustomTicketLine(
      type: type ?? this.type,
      text: text ?? this.text,
      bold: bold ?? this.bold,
      center: center ?? this.center,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'text': text,
        'bold': bold,
        'center': center,
        'qty': qty,
        'unitPrice': unitPrice,
        'amount': amount,
      };

  factory CustomTicketLine.fromJson(Map<String, dynamic> json) {
    return CustomTicketLine(
      type: CustomTicketLineType.fromName(json['type'] as String?),
      text: (json['text'] as String?) ?? '',
      bold: json['bold'] as bool? ?? false,
      center: json['center'] as bool? ?? false,
      qty: (json['qty'] as String?) ?? '',
      unitPrice: (json['unitPrice'] as String?) ?? '',
      amount: (json['amount'] as String?) ?? '',
    );
  }
}

/// Plantilla editable de ticket térmico propio.
class CustomTicketTemplate {
  const CustomTicketTemplate({
    required this.id,
    required this.name,
    this.title = '',
    this.lines = const [],
    this.showLogo = false,
    this.logoBytes,
    this.footer = '',
    this.showTotals = true,
    this.currencySymbol = 'S/',
    this.subtotalLabel = 'Subtotal',
    this.subtotal = '',
    this.taxLabel = 'IGV',
    this.tax = '',
    this.totalLabel = 'TOTAL',
    this.total = '',
    this.showQr = false,
    this.qrData = '',
    this.showBarcode = false,
    this.barcodeData = '',
    this.updatedAtMs = 0,
  });

  static const maxNameLength = 80;
  static const maxTitleLength = 120;
  static const maxFooterLength = 240;
  static const maxLineTextLength = 200;
  static const maxCodeLength = 200;

  final String id;
  final String name;
  final String title;
  final List<CustomTicketLine> lines;
  final bool showLogo;
  final Uint8List? logoBytes;
  final String footer;
  final bool showTotals;
  final String currencySymbol;
  final String subtotalLabel;
  final String subtotal;
  final String taxLabel;
  final String tax;
  final String totalLabel;
  final String total;
  final bool showQr;
  final String qrData;
  final bool showBarcode;
  final String barcodeData;
  final int updatedAtMs;

  CustomTicketTemplate copyWith({
    String? id,
    String? name,
    String? title,
    List<CustomTicketLine>? lines,
    bool? showLogo,
    Uint8List? logoBytes,
    bool clearLogo = false,
    String? footer,
    bool? showTotals,
    String? currencySymbol,
    String? subtotalLabel,
    String? subtotal,
    String? taxLabel,
    String? tax,
    String? totalLabel,
    String? total,
    bool? showQr,
    String? qrData,
    bool? showBarcode,
    String? barcodeData,
    int? updatedAtMs,
  }) {
    return CustomTicketTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      lines: lines ?? this.lines,
      showLogo: showLogo ?? this.showLogo,
      logoBytes: clearLogo ? null : (logoBytes ?? this.logoBytes),
      footer: footer ?? this.footer,
      showTotals: showTotals ?? this.showTotals,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      subtotalLabel: subtotalLabel ?? this.subtotalLabel,
      subtotal: subtotal ?? this.subtotal,
      taxLabel: taxLabel ?? this.taxLabel,
      tax: tax ?? this.tax,
      totalLabel: totalLabel ?? this.totalLabel,
      total: total ?? this.total,
      showQr: showQr ?? this.showQr,
      qrData: qrData ?? this.qrData,
      showBarcode: showBarcode ?? this.showBarcode,
      barcodeData: barcodeData ?? this.barcodeData,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'title': title,
        'lines': lines.map((e) => e.toJson()).toList(),
        'showLogo': showLogo,
        if (logoBytes != null && logoBytes!.isNotEmpty)
          'logoB64': base64Encode(logoBytes!),
        'footer': footer,
        'showTotals': showTotals,
        'currencySymbol': currencySymbol,
        'subtotalLabel': subtotalLabel,
        'subtotal': subtotal,
        'taxLabel': taxLabel,
        'tax': tax,
        'totalLabel': totalLabel,
        'total': total,
        'showQr': showQr,
        'qrData': qrData,
        'showBarcode': showBarcode,
        'barcodeData': barcodeData,
        'updatedAtMs': updatedAtMs,
      };

  factory CustomTicketTemplate.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final lines = <CustomTicketLine>[];
    if (rawLines is List) {
      for (final e in rawLines) {
        if (e is Map) {
          lines.add(CustomTicketLine.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    Uint8List? logo;
    final b64 = json['logoB64'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      try {
        final decoded = base64Decode(b64);
        if (decoded.isNotEmpty) logo = decoded;
      } catch (_) {}
    }
    return CustomTicketTemplate(
      id: (json['id'] as String?) ?? '',
      name: _clip((json['name'] as String?) ?? '', maxNameLength),
      title: _clip((json['title'] as String?) ?? '', maxTitleLength),
      lines: lines,
      showLogo: json['showLogo'] as bool? ?? false,
      logoBytes: logo,
      footer: _clip((json['footer'] as String?) ?? '', maxFooterLength),
      showTotals: json['showTotals'] as bool? ?? true,
      currencySymbol: ((json['currencySymbol'] as String?) ?? 'S/').trim().isEmpty
          ? 'S/'
          : (json['currencySymbol'] as String).trim(),
      subtotalLabel: (json['subtotalLabel'] as String?) ?? 'Subtotal',
      subtotal: (json['subtotal'] as String?) ?? '',
      taxLabel: (json['taxLabel'] as String?) ?? 'IGV',
      tax: (json['tax'] as String?) ?? '',
      totalLabel: (json['totalLabel'] as String?) ?? 'TOTAL',
      total: (json['total'] as String?) ?? '',
      showQr: json['showQr'] as bool? ?? false,
      qrData: _clip((json['qrData'] as String?) ?? '', maxCodeLength),
      showBarcode: json['showBarcode'] as bool? ?? false,
      barcodeData: _clip((json['barcodeData'] as String?) ?? '', maxCodeLength),
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  /// Vista previa en pantalla (texto monoespace aproximado).
  List<String> previewLines({int cols = 32}) {
    final out = <String>[];
    if (showLogo && logoBytes != null && logoBytes!.isNotEmpty) {
      out.add('[LOGO]');
    }
    if (title.trim().isNotEmpty) {
      out.addAll(_wrapCenter(title.trim(), cols));
    }
    if (title.trim().isNotEmpty || (showLogo && logoBytes != null)) {
      out.add('-' * cols);
    }
    for (final line in lines) {
      if (line.isItem) {
        final qty = line.qty.trim().isEmpty ? '1' : line.qty.trim();
        final desc = line.text.trim().isEmpty ? '-' : line.text.trim();
        final head = '$qty  $desc';
        out.addAll(_wrap(head, cols));
        final right = [
          if (line.unitPrice.trim().isNotEmpty) line.unitPrice.trim(),
          if (line.amount.trim().isNotEmpty) line.amount.trim(),
        ].join('  ');
        if (right.isNotEmpty) {
          final padded = right.length >= cols
              ? right.substring(right.length - cols)
              : right.padLeft(cols);
          out.add(padded);
        }
      } else {
        final t = line.text;
        if (t.trim().isEmpty) {
          out.add('');
        } else if (line.center) {
          out.addAll(_wrapCenter(t, cols));
        } else {
          out.addAll(_wrap(t, cols));
        }
      }
    }
    if (showTotals &&
        (subtotal.trim().isNotEmpty ||
            tax.trim().isNotEmpty ||
            total.trim().isNotEmpty)) {
      out.add('-' * cols);
      final cur =
          currencySymbol.trim().isEmpty ? 'S/' : currencySymbol.trim();
      if (subtotal.trim().isNotEmpty) {
        out.add(_pair(cols, subtotalLabel, '$cur ${subtotal.trim()}'));
      }
      if (tax.trim().isNotEmpty) {
        out.add(_pair(cols, taxLabel, '$cur ${tax.trim()}'));
      }
      if (total.trim().isNotEmpty) {
        out.add(_pair(cols, totalLabel, '$cur ${total.trim()}'));
      }
    }
    if (showQr && qrData.trim().isNotEmpty) {
      out.add('[QR]');
      out.addAll(_wrapCenter(qrData.trim(), cols));
    }
    if (showBarcode && barcodeData.trim().isNotEmpty) {
      out.add('[BARCODE]');
      out.addAll(_wrapCenter(barcodeData.trim(), cols));
    }
    if (footer.trim().isNotEmpty) {
      out.add('-' * cols);
      for (final part in footer
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n')) {
        if (part.trim().isEmpty) {
          out.add('');
        } else {
          out.addAll(_wrapCenter(part.trim(), cols));
        }
      }
    }
    return out;
  }

  static String _clip(String raw, int max) {
    final t = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (t.length <= max) return t;
    return t.substring(0, max);
  }

  static List<String> _wrap(String text, int width) {
    final t = text.trimRight();
    if (width < 1) return [t];
    if (t.isEmpty) return [''];
    if (t.length <= width) return [t];
    final out = <String>[];
    var rest = t;
    while (rest.length > width) {
      var cut = rest.lastIndexOf(' ', width);
      if (cut < width ~/ 3) cut = width;
      out.add(rest.substring(0, cut).trimRight());
      rest = rest.substring(cut).trimLeft();
    }
    if (rest.isNotEmpty) out.add(rest);
    return out.isEmpty ? [''] : out;
  }

  static List<String> _wrapCenter(String text, int width) {
    return _wrap(text, width).map((line) {
      if (line.length >= width) return line;
      final pad = (width - line.length) ~/ 2;
      return (' ' * pad) + line;
    }).toList();
  }

  static String _pair(int width, String left, String right) {
    final l = left.trim();
    final r = right.trim();
    if (l.length + 1 + r.length >= width) return ' ';
    return l + (' ' * (width - l.length - r.length)) + r;
  }
}
