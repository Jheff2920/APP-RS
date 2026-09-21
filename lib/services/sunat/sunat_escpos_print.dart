import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../models/paper_width.dart';
import '../../models/saved_printer.dart';
import '../escpos_capability_profile.dart';
import '../escpos_feed.dart';
import 'sunat_logo.dart';
import 'sunat_print_settings.dart';
import 'sunat_ticket.dart';

class SunatEscPosPrint {
  static Future<List<int>> build(
    SavedPrinter printer,
    SunatTicket ticket, {
    SunatPrintSettings settings = const SunatPrintSettings(),
    Uint8List? logoBytes,
  }) async {
    final profile = await EscPosCapabilityProfile.load;
    final paperSize =
        printer.paper == PaperWidth.mm58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paperSize, profile);
    final margins = printer.margins;

    final totalCols = printer.paper.charsPerLine;
    final leftPad = _charsForMm(printer.paper, margins.leftMm);
    final rightPad = _charsForMm(printer.paper, margins.rightMm);
    final usable = (totalCols - leftPad - rightPad).clamp(8, totalCols);
    final safeLeft = leftPad.clamp(0, totalCols - usable);
    final wide = printer.paper == PaperWidth.mm80;
    final format = settings.format;
    final compact = format == SunatTicketFormat.compacto;
    final detailed = format == SunatTicketFormat.detallado;
    final money = ticket.showTotals;
    final columns = money && usable >= 36;

    List<int> bytes = [];
    bytes += generator.reset();

    if (logoBytes != null && logoBytes.isNotEmpty) {
      final raster = SunatLogo.rasterForPaper(
        logoBytes,
        dotsWidth: printer.dotsWidth,
      );
      if (raster.isNotEmpty) {
        bytes += raster;
        bytes += [0x0A];
      }
    }

    void left(String text, {PosStyles styles = const PosStyles()}) {
      for (final part in _wrap(latin1Safe(text), usable)) {
        bytes += generator.text(
          '${' ' * safeLeft}$part',
          styles: styles,
        );
      }
    }

    void center(String text, {PosStyles styles = const PosStyles()}) {
      for (final part in _wrap(latin1Safe(text), usable)) {
        bytes += generator.text(
          part,
          styles: PosStyles(
            align: PosAlign.center,
            bold: styles.bold,
            height: styles.height,
            width: styles.width,
          ),
        );
      }
    }

    void sep() => left('-' * usable);

    if (ticket.supplierName.isNotEmpty) {
      center(
        ticket.supplierName,
        styles: const PosStyles(bold: true),
      );
    }
    if (ticket.supplierRuc.isNotEmpty) {
      center('RUC: ${ticket.supplierRuc}');
    }
    if (ticket.supplierAddress.isNotEmpty) {
      center(ticket.supplierAddress);
    }

    sep();
    center(
      ticket.documentTypeLabel,
      styles: const PosStyles(bold: true),
    );
    if (ticket.documentId.isNotEmpty) {
      center(
        ticket.documentId,
        styles: PosStyles(
          bold: true,
          height: compact ? PosTextSize.size1 : PosTextSize.size2,
        ),
      );
    }
    if (ticket.issueDate.isNotEmpty) {
      final fecha = _formatDate(ticket.issueDate);
      final hora = detailed ? _formatTime(ticket.issueTime) : '';
      final fechaTxt = hora.isEmpty ? 'Fecha: $fecha' : 'Fecha: $fecha $hora';
      if (!compact &&
          hora.isEmpty &&
          ticket.currency.isNotEmpty &&
          fechaTxt.length + ticket.currency.length + 1 < usable) {
        left(_pair(usable, fechaTxt, ticket.currency));
      } else {
        left(fechaTxt);
      }
    }
    if (detailed && ticket.currency.isNotEmpty) {
      left('Moneda: ${ticket.currency}');
    }
    if (ticket.referenceId.isNotEmpty) {
      final label = compact ? 'Afecta' : 'Doc. afectado';
      left('$label: ${ticket.referenceId}');
    }

    sep();
    if (compact) {
      left('Cliente: ${ticket.customerName.ifBlank('---')}');
    } else {
      left('CLIENTE', styles: const PosStyles(bold: true));
      left(ticket.customerName.ifBlank('---'));
    }
    final doc = [
      if (ticket.customerDocType.isNotEmpty) _docTypeLabel(ticket.customerDocType),
      if (ticket.customerDoc.isNotEmpty) ticket.customerDoc,
    ].join(' ');
    if (doc.isNotEmpty) left(doc);
    if (detailed && ticket.customerAddress.isNotEmpty) {
      left(ticket.customerAddress);
    }
    for (final detail in ticket.details) {
      left(detail);
    }

    sep();
    final qtyW = detailed ? 8 : 5;
    final descW = columns ? (usable - qtyW - 17).clamp(8, usable) : usable;
    if (columns) {
      left(_cols(
        ['CANT', 'DESCRIPCION', 'P.U.', 'IMP.'],
        [qtyW, descW, 8, 9],
      ));
    } else {
      left('CANT  DESCRIPCION');
    }
    for (var i = 0; i < ticket.lines.length; i++) {
      final line = ticket.lines[i];
      final qty = _qtyLabel(line, withUnit: detailed);
      if (columns) {
        final descLines = _wrap(line.description, descW);
        left(
          _cols(
            [qty, descLines.first, _money(line.unitPrice), _money(line.amount)],
            [qtyW, descW, 8, 9],
          ),
        );
        for (final extra in descLines.skip(1)) {
          left(_cols(['', extra, '', ''], [qtyW, descW, 8, 9]));
        }
      } else {
        final room = (usable - qty.length - 1).clamp(4, usable);
        final descLines = _wrap(line.description, room);
        left('$qty ${descLines.first}');
        for (final extra in descLines.skip(1)) {
          left('${' ' * (qty.length + 1)}$extra');
        }
        if (money) {
          left(_right(usable, '${_money(line.unitPrice)}  ${_money(line.amount)}'));
        }
      }
      if (detailed && i < ticket.lines.length - 1) {
        bytes += [0x0A];
      }
    }

    if (money) {
      sep();
      final cur = ticket.currencySymbol;
      left(_pair(usable, 'OP. GRAVADA', '$cur ${_money(ticket.subtotal)}'));
      left(_pair(usable, 'IGV', '$cur ${_money(ticket.igv)}'));
      left(
        _pair(usable, 'TOTAL', '$cur ${_money(ticket.total)}'),
        styles: const PosStyles(bold: true),
      );
    }
    if (settings.showLegend && ticket.legend.isNotEmpty) {
      left(ticket.legend);
    }

    sep();
    if (settings.showQr && ticket.qrPayload.replaceAll('|', '').isNotEmpty) {
      bytes += generator.qrcode(
        ticket.qrPayload,
        align: PosAlign.center,
        size: wide && !compact ? QRSize.size5 : QRSize.size4,
      );
      center('Consulte en SUNAT');
    }
    center(compact ? 'Gracias' : 'Gracias por su compra');

    final note = SunatPrintSettings.normalizeNote(settings.footerNote);
    if (note.isNotEmpty) {
      sep();
      for (final line in note.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          bytes += [0x0A];
        } else {
          center(trimmed);
        }
      }
    }

    bytes += EscPosFeed.finishJob(
      bottomMm: margins.bottomMm,
      paperDotsWidth: printer.dotsWidth,
      cut: printer.cut,
      dotsPerMm: printer.dpi.dotsPerMm,
      network: printer.type == PrinterLinkType.network,
    );
    return bytes;
  }

  /// CP437/latin1 de las térmicas no trae comillas tipográficas del XML SUNAT.
  static String latin1Safe(String text) {
    var t = text
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"')
        .replaceAll('\u201e', '"')
        .replaceAll('\u00ab', '"')
        .replaceAll('\u00bb', '"')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201a', "'")
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2212', '-')
        .replaceAll('\u2026', '...')
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u200b', '');
    final out = StringBuffer();
    for (final r in t.runes) {
      if (r == 0x09 ||
          r == 0x0A ||
          r == 0x0D ||
          (r >= 0x20 && r <= 0x7E) ||
          (r >= 0xA0 && r <= 0xFF)) {
        out.writeCharCode(r);
      } else {
        out.write('?');
      }
    }
    return out.toString();
  }

  static int _charsForMm(PaperWidth paper, double mm) {
    if (mm <= 0) return 0;
    final mmPerChar = paper.printableWidthMm / paper.charsPerLine;
    return (mm / mmPerChar).round().clamp(0, paper.charsPerLine - 8);
  }

  static List<String> _wrap(String text, int width) {
    final t = text.trim();
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
    if (left.length + 1 + right.length >= width) {
      return '$left $right';
    }
    return left + (' ' * (width - left.length - right.length)) + right;
  }

  static String _right(int width, String text) {
    if (text.length >= width) return text;
    return text.padLeft(width);
  }

  static String _money(double n) => n.toStringAsFixed(2);

  static String _qty(double n) {
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    return n.toStringAsFixed(2);
  }

  static String _qtyLabel(SunatLine line, {required bool withUnit}) {
    final qty = _qty(line.quantity);
    if (!withUnit || line.unit.trim().isEmpty) return qty;
    return '$qty ${_unitLabel(line.unit)}';
  }

  static String _unitLabel(String code) {
    switch (code.trim().toUpperCase()) {
      case 'NIU':
      case 'ZZ':
      case 'C62':
        return 'UND';
      case 'KGM':
        return 'KG';
      case 'LTR':
        return 'LT';
      case 'MTR':
        return 'M';
      default:
        final raw = code.trim().toUpperCase();
        return raw.length > 4 ? raw.substring(0, 4) : raw;
    }
  }

  static String _formatDate(String raw) {
    final p = raw.split('-');
    if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
    return raw;
  }

  static String _formatTime(String raw) {
    final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch(raw.trim());
    if (match == null) return '';
    return '${match.group(1)}:${match.group(2)}';
  }

  static String _docTypeLabel(String code) {
    switch (code) {
      case '1':
        return 'DNI';
      case '6':
        return 'RUC';
      case '4':
        return 'CE';
      case '7':
        return 'PAS';
      default:
        return 'DOC';
    }
  }
}

extension on String {
  String ifBlank(String fallback) => trim().isEmpty ? fallback : this;
}
