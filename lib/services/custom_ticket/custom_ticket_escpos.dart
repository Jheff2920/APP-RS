import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../models/paper_width.dart';
import '../../models/saved_printer.dart';
import '../escpos_capability_profile.dart';
import '../escpos_feed.dart';
import '../sunat/sunat_escpos_print.dart';
import '../sunat/sunat_logo.dart';
import 'custom_ticket.dart';

/// Arma bytes ESC/POS para un ticket propio.
///
/// Layout de ítems alineado a boleta/SUNAT claro: columnas
/// CANT | DESCRIPCION | P.U. | IMP. en 58 mm y 80 mm (anchos adaptativos).
/// Montos con formato `150.00` y símbolo `S/ 150.00`.
class CustomTicketEscPos {
  static Future<List<int>> build(
    SavedPrinter printer,
    CustomTicketTemplate ticket, {
    Uint8List? logoOverride,
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

    List<int> bytes = [];
    bytes += generator.reset();

    final logoBytes =
        logoOverride ?? (ticket.showLogo ? ticket.logoBytes : null);
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
      for (final part in _wrap(SunatEscPosPrint.latin1Safe(text), usable)) {
        bytes += generator.text(
          '${' ' * safeLeft}$part',
          styles: styles,
        );
      }
    }

    void center(String text, {PosStyles styles = const PosStyles()}) {
      for (final part in _wrap(SunatEscPosPrint.latin1Safe(text), usable)) {
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

    final company = ticket.companyName.trim();
    final ruc = ticket.ruc.trim();
    final addr = ticket.address.trim();
    if (company.isNotEmpty) {
      center(company, styles: const PosStyles(bold: true));
    }
    if (ruc.isNotEmpty) {
      center('RUC: $ruc');
    }
    if (addr.isNotEmpty) {
      center(addr);
    }

    final title = ticket.title.trim();
    if (title.isNotEmpty) {
      center(
        title,
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
        ),
      );
    }
    if (company.isNotEmpty ||
        ruc.isNotEmpty ||
        addr.isNotEmpty ||
        title.isNotEmpty ||
        (logoBytes != null && logoBytes.isNotEmpty)) {
      sep();
    }

    // Columnas en 58/80 cuando hay espacio (>= 28). Patrón SUNAT claro.
    final moneyCols = ticket.showTotals && usable >= 28;
    // qtyW >= 5 so header "CANT" keeps a trailing space before DESCRIPCION.
    final qtyW = 5;
    final puW = usable >= 40 ? 8 : 7;
    final impW = usable >= 40 ? 9 : 8;
    final descW =
        moneyCols ? (usable - qtyW - puW - impW).clamp(6, usable) : usable;
    final widths = [qtyW, descW, puW, impW];
    var wroteItemHeader = false;

    for (final line in ticket.lines) {
      if (line.isItem) {
        if (!wroteItemHeader) {
          if (moneyCols) {
            left(_cols(
              ['CANT', 'DESCRIPCION', 'P.U.', 'IMP.'],
              widths,
            ));
          } else {
            left('CANT  DESCRIPCION');
          }
          wroteItemHeader = true;
        }
        final qty = line.qty.trim().isEmpty ? '1' : line.qty.trim();
        final descRaw = line.text.trim().isEmpty ? '-' : line.text.trim();
        final desc = SunatEscPosPrint.latin1Safe(descRaw);
        final pu = line.unitPrice.trim().isEmpty
            ? ''
            : CustomTicketMoney.formatRaw(line.unitPrice);
        final imp = line.amount.trim().isEmpty
            ? ''
            : CustomTicketMoney.formatRaw(line.amount);
        if (moneyCols) {
          final descLines = _wrap(desc, descW);
          left(_cols([qty, descLines.first, pu, imp], widths));
          for (final extra in descLines.skip(1)) {
            left(_cols(['', extra, '', ''], widths));
          }
        } else {
          final room = (usable - qty.length - 1).clamp(4, usable);
          final descLines = _wrap(desc, room);
          left('$qty ${descLines.first}');
          for (final extra in descLines.skip(1)) {
            left('${' ' * (qty.length + 1)}$extra');
          }
          final prices = [
            if (pu.isNotEmpty) pu,
            if (imp.isNotEmpty) imp,
          ].join('  ');
          if (prices.isNotEmpty) {
            left(_right(usable, prices));
          }
        }
      } else {
        wroteItemHeader = false;
        final text = line.text;
        if (text.trim().isEmpty) {
          bytes += [0x0A];
          continue;
        }
        final styles = PosStyles(bold: line.bold);
        if (line.center) {
          center(text, styles: styles);
        } else {
          left(text, styles: styles);
        }
      }
    }

    if (ticket.showTotals &&
        (ticket.subtotal.trim().isNotEmpty ||
            ticket.tax.trim().isNotEmpty ||
            ticket.total.trim().isNotEmpty)) {
      sep();
      final cur = ticket.currencySymbol.trim().isEmpty
          ? 'S/'
          : ticket.currencySymbol.trim();
      if (ticket.subtotal.trim().isNotEmpty) {
        left(_pair(
          usable,
          ticket.subtotalLabel,
          CustomTicketMoney.withSymbolRaw(cur, ticket.subtotal),
        ));
      }
      if (ticket.tax.trim().isNotEmpty) {
        left(_pair(
          usable,
          ticket.taxLabel,
          CustomTicketMoney.withSymbolRaw(cur, ticket.tax),
        ));
      }
      if (ticket.total.trim().isNotEmpty) {
        left(
          _pair(
            usable,
            ticket.totalLabel,
            CustomTicketMoney.withSymbolRaw(cur, ticket.total),
          ),
          styles: const PosStyles(bold: true),
        );
      }
    }

    if (ticket.showQr && ticket.qrData.trim().isNotEmpty) {
      sep();
      bytes += generator.qrcode(
        ticket.qrData.trim(),
        align: PosAlign.center,
        size: wide ? QRSize.size7 : QRSize.size6,
      );
    }

    if (ticket.showBarcode && ticket.barcodeData.trim().isNotEmpty) {
      final payload = ticket.barcodeData.trim();
      try {
        final data = '{B$payload}'.split('');
        bytes += generator.barcode(
          Barcode.code128(data),
          align: PosAlign.center,
          height: 60,
          width: 2,
          textPos: BarcodeText.below,
        );
      } catch (_) {
        center(payload);
      }
    }

    final note = ticket.footer
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (note.isNotEmpty) {
      sep();
      for (final part in note.split('\n')) {
        final trimmed = part.trim();
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
}
