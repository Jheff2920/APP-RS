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
    this.id = '',
    this.type = CustomTicketLineType.text,
    this.text = '',
    this.bold = false,
    this.center = false,
    this.qty = '',
    this.unitPrice = '',
    this.amount = '',
  });

  /// Stable id for list keys / TextEditingControllers across rebuilds.
  final String id;
  final CustomTicketLineType type;
  final String text;
  final bool bold;
  final bool center;
  final String qty;
  final String unitPrice;
  final String amount;

  bool get isItem => type == CustomTicketLineType.item;

  CustomTicketLine copyWith({
    String? id,
    CustomTicketLineType? type,
    String? text,
    bool? bold,
    bool? center,
    String? qty,
    String? unitPrice,
    String? amount,
  }) {
    return CustomTicketLine(
      id: id ?? this.id,
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
        if (id.isNotEmpty) 'id': id,
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
      id: (json['id'] as String?) ?? '',
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

/// Parseo/formato de dinero para tickets propios.
///
/// Modelo Peru POS: los montos de ítem son **sin IGV** (base imponible).
/// Op. Gravada = suma(importes de línea), IGV = Op. Gravada × 18%,
/// Total = Op. Gravada + IGV. Coincide con etiquetas tipo boleta (Op. Gravada /
/// IGV 18% / Total).
class CustomTicketMoney {
  static const igvRate = 0.18;

  /// Acepta `150`, `150.5`, `150,50`, `S/ 150.00`, miles con punto/espacio.
  static double? parse(String? raw) {
    if (raw == null) return null;
    var t = raw.trim();
    if (t.isEmpty) return null;
    t = t.replaceAll(RegExp(r'[Ss]/'), '');
    t = t.replaceAll(' ', '');
    t = t.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (t.isEmpty || t == '-' || t == '.' || t == ',') return null;
    if (t.contains(',') && t.contains('.')) {
      if (t.lastIndexOf(',') > t.lastIndexOf('.')) {
        t = t.replaceAll('.', '').replaceAll(',', '.');
      } else {
        t = t.replaceAll(',', '');
      }
    } else if (t.contains(',')) {
      t = t.replaceAll(',', '.');
    }
    return double.tryParse(t);
  }

  static String format(double n) => n.toStringAsFixed(2);

  static String formatRaw(String raw) {
    final v = parse(raw);
    if (v == null) return raw.trim();
    return format(v);
  }

  static String withSymbol(String symbol, double n) {
    final cur = symbol.trim().isEmpty ? 'S/' : symbol.trim();
    return '$cur ${format(n)}';
  }

  static String withSymbolRaw(String symbol, String raw) {
    final v = parse(raw);
    if (v == null) {
      final cur = symbol.trim().isEmpty ? 'S/' : symbol.trim();
      final t = raw.trim();
      if (t.isEmpty) return '';
      return '$cur $t';
    }
    return withSymbol(symbol, v);
  }
}

/// Totales calculados desde ítems (montos sin IGV).
class CustomTicketTotals {
  const CustomTicketTotals({
    required this.subtotal,
    required this.igv,
    required this.total,
  });

  final double subtotal;
  final double igv;
  final double total;

  static CustomTicketTotals fromLines(List<CustomTicketLine> lines) {
    var sum = 0.0;
    for (final line in lines) {
      if (!line.isItem) continue;
      final amt = CustomTicketMoney.parse(line.amount);
      if (amt != null) {
        sum += amt;
        continue;
      }
      final q = CustomTicketMoney.parse(line.qty) ?? 1.0;
      final pu = CustomTicketMoney.parse(line.unitPrice);
      if (pu != null) sum += q * pu;
    }
    final sub = _round2(sum);
    final igv = _round2(sum * CustomTicketMoney.igvRate);
    return CustomTicketTotals(
      subtotal: sub,
      igv: igv,
      total: _round2(sub + igv),
    );
  }

  static double _round2(double n) => (n * 100).roundToDouble() / 100.0;
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
    this.companyName = '',
    this.ruc = '',
    this.address = '',
    this.footer = '',
    this.showTotals = true,
    this.currencySymbol = 'S/',
    this.subtotalLabel = 'Op. Gravada',
    this.subtotal = '',
    this.taxLabel = 'IGV 18%',
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
  static const maxCompanyNameLength = 120;
  static const maxRucLength = 20;
  static const maxAddressLength = 200;
  static const maxFooterLength = 240;
  static const maxLineTextLength = 200;
  static const maxCodeLength = 200;

  final String id;
  final String name;
  final String title;
  final List<CustomTicketLine> lines;
  final bool showLogo;
  final Uint8List? logoBytes;
  /// Nombre de tienda/empresa bajo el logo (cabecera tipo emisor SUNAT).
  final String companyName;
  /// RUC de la tienda/empresa.
  final String ruc;
  /// Dirección / ubicación de la tienda.
  final String address;
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
    String? companyName,
    String? ruc,
    String? address,
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
      companyName: companyName ?? this.companyName,
      ruc: ruc ?? this.ruc,
      address: address ?? this.address,
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
        'companyName': companyName,
        'ruc': ruc,
        'address': address,
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
      companyName: _clip((json['companyName'] as String?) ?? '', maxCompanyNameLength),
      ruc: _clip((json['ruc'] as String?) ?? '', maxRucLength),
      address: _clip((json['address'] as String?) ?? '', maxAddressLength),
      footer: _clip((json['footer'] as String?) ?? '', maxFooterLength),
      showTotals: json['showTotals'] as bool? ?? true,
      currencySymbol: ((json['currencySymbol'] as String?) ?? 'S/').trim().isEmpty
          ? 'S/'
          : (json['currencySymbol'] as String).trim(),
      subtotalLabel: (json['subtotalLabel'] as String?) ?? 'Op. Gravada',
      subtotal: (json['subtotal'] as String?) ?? '',
      taxLabel: (json['taxLabel'] as String?) ?? 'IGV 18%',
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

  /// Vista previa en pantalla (texto monoespace; columnas tipo boleta/SUNAT).
  List<String> previewLines({int cols = 32}) {
    final out = <String>[];
    if (showLogo && logoBytes != null && logoBytes!.isNotEmpty) {
      out.add('[LOGO]');
    }
    final company = companyName.trim();
    final rucTrim = ruc.trim();
    final addr = address.trim();
    if (company.isNotEmpty) {
      out.addAll(_wrapCenter(company, cols));
    }
    if (rucTrim.isNotEmpty) {
      out.addAll(_wrapCenter('RUC: $rucTrim', cols));
    }
    if (addr.isNotEmpty) {
      out.addAll(_wrapCenter(addr, cols));
    }
    // Title is form-only; header already shows company / RUC / address.
    final hasHeader = company.isNotEmpty ||
        rucTrim.isNotEmpty ||
        addr.isNotEmpty ||
        (showLogo && logoBytes != null);
    if (hasHeader) {
      out.add('-' * cols);
    }

    final moneyCols = showTotals && cols >= 28;
    // Keep quantity compact while fitting 2- and 3-digit values.
    final qtyW = 3;
    final puW = cols >= 40 ? 8 : 7;
    final impW = cols >= 40 ? 9 : 8;
    final descW =
        moneyCols ? (cols - qtyW - puW - impW).clamp(6, cols) : cols;
    var wroteItemHeader = false;

    for (final line in lines) {
      if (line.isItem) {
        if (!wroteItemHeader) {
          if (moneyCols) {
            out.add(_cols(
              ['Ct', 'DESCRIPCION', 'P.U.', 'IMP.'],
              [qtyW, descW, puW, impW],
            ));
          } else {
            out.add('Ct DESCRIPCION');
          }
          wroteItemHeader = true;
        }
        final qty = line.qty.trim().isEmpty ? '1' : line.qty.trim();
        final desc = line.text.trim().isEmpty ? '-' : line.text.trim();
        final pu = line.unitPrice.trim().isEmpty
            ? ''
            : CustomTicketMoney.formatRaw(line.unitPrice);
        final imp = line.amount.trim().isEmpty
            ? ''
            : CustomTicketMoney.formatRaw(line.amount);
        if (moneyCols) {
          final descLines = _wrap(desc, descW);
          out.add(_cols([qty, descLines.first, pu, imp], [qtyW, descW, puW, impW]));
          for (final extra in descLines.skip(1)) {
            out.add(_cols(['', extra, '', ''], [qtyW, descW, puW, impW]));
          }
        } else {
          final room = (cols - qty.length - 1).clamp(4, cols);
          final descLines = _wrap(desc, room);
          out.add('$qty ${descLines.first}');
          for (final extra in descLines.skip(1)) {
            out.add('${' ' * (qty.length + 1)}$extra');
          }
          final prices = [
            if (pu.isNotEmpty) pu,
            if (imp.isNotEmpty) imp,
          ].join('  ');
          if (prices.isNotEmpty) {
            out.add(prices.length >= cols
                ? prices.substring(prices.length - cols)
                : prices.padLeft(cols));
          }
        }
      } else {
        wroteItemHeader = false;
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
        out.add(_pair(
          cols,
          subtotalLabel,
          CustomTicketMoney.withSymbolRaw(cur, subtotal),
        ));
      }
      if (tax.trim().isNotEmpty) {
        out.add(_pair(
          cols,
          taxLabel,
          CustomTicketMoney.withSymbolRaw(cur, tax),
        ));
      }
      if (total.trim().isNotEmpty) {
        out.add(_pair(
          cols,
          totalLabel,
          CustomTicketMoney.withSymbolRaw(cur, total),
        ));
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

  static String _cols(List<String> cells, List<int> widths) {
    final buf = StringBuffer();
    for (var i = 0; i < cells.length; i++) {
      final w = widths[i];
      var c = cells[i];
      if (c.length > w) c = c.substring(0, w);
      final right = i >= cells.length - 2;
      buf.write(right ? c.padLeft(w) : c.padRight(w));
    }
    return buf.toString();
  }

  static String _pair(int width, String left, String right) {
    final l = left.trim();
    final r = right.trim();
    if (l.length + 1 + r.length >= width) return '$l $r';
    return l + (' ' * (width - l.length - r.length)) + r;
  }
}
