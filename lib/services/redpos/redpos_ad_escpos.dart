import '../../models/paper_width.dart';
import '../../models/saved_printer.dart';
import 'redpos_config.dart';

/// Pie de publicidad ESC/POS: pegado al ticket, luego el margen y el corte.
class RedPosAdEscPos {
  static const lines = <String>[
    'App de uso gratuito.',
    'Sin publicidad: equipo RedPOS',
    'o suscripcion.',
  ];

  static List<int> footerBytes({
    required PaperWidth paper,
    String? siteUrl,
  }) {
    final width = paper.charsPerLine;
    final stars = '*' * width;
    final url = (siteUrl ?? RedPosConfig.siteUrl).trim();
    final out = <int>[
      0x0a, // un salto: pegado al PDF, no encima
      0x1b, 0x61, 0x01, // center
      0x1b, 0x21, 0x00, // font A
    ];
    void line(String text) {
      out.addAll(text.codeUnits);
      out.add(0x0a);
    }

    line(stars);
    for (final row in lines) {
      line(_fit(row, width));
    }
    if (url.isNotEmpty) line(_fit(url, width));
    line(stars);
    out.add(0x0a);
    out.addAll(const [0x1b, 0x61, 0x00]); // left
    return out;
  }

  static List<int> maybeWrap(
    List<int> ticket, {
    required SavedPrinter printer,
    required bool adsFree,
  }) {
    if (adsFree) return ticket;
    return insertBeforeFeedAndCut(
      ticket,
      footerBytes(paper: printer.paper),
      printer.cut.escPosBytes,
    );
  }

  /// Inserta el pie después del contenido y antes del margen inferior + corte.
  static List<int> insertBeforeFeedAndCut(
    List<int> ticket,
    List<int> footer,
    List<int> cut,
  ) {
    var end = ticket.length;
    if (cut.isNotEmpty && _endsWith(ticket, cut)) {
      end -= cut.length;
    }
    final insertAt = _trailingBlankRasterStart(ticket, end);
    var ad = footer;
    if (insertAt >= end) {
      // Sin margen de fábrica: avance para que la cuchilla no coma el texto.
      ad = [...footer, 0x1b, 0x64, 0x05];
    }
    return [
      ...ticket.sublist(0, insertAt),
      ...ad,
      ...ticket.sublist(insertAt),
    ];
  }

  /// Compatibilidad con tests antiguos.
  static List<int> insertBeforeCut(
    List<int> ticket,
    List<int> footer,
    List<int> cut,
  ) =>
      insertBeforeFeedAndCut(ticket, footer, cut);

  static bool _endsWith(List<int> hay, List<int> needle) {
    if (needle.isEmpty || hay.length < needle.length) return false;
    final off = hay.length - needle.length;
    for (var i = 0; i < needle.length; i++) {
      if (hay[off + i] != needle[i]) return false;
    }
    return true;
  }

  /// Inicio de las franjas GS v 0 en blanco al final (margen inferior).
  static int _trailingBlankRasterStart(List<int> ticket, int end) {
    var i = end;
    while (true) {
      if (i < 8) return i;
      var skipped = false;
      final minHeader = (i - 8 - 96 * 80).clamp(0, i);
      for (var headerAt = i - 8; headerAt >= minHeader; headerAt--) {
        if (ticket[headerAt] != 0x1d ||
            ticket[headerAt + 1] != 0x76 ||
            ticket[headerAt + 2] != 0x30) {
          continue;
        }
        final x = ticket[headerAt + 4] | (ticket[headerAt + 5] << 8);
        final y = ticket[headerAt + 6] | (ticket[headerAt + 7] << 8);
        if (x < 1 || y < 1 || x > 96 || y > 512) continue;
        if (headerAt + 8 + x * y != i) continue;
        var blank = true;
        for (var k = headerAt + 8; k < i; k++) {
          if (ticket[k] != 0) {
            blank = false;
            break;
          }
        }
        if (!blank) return i;
        i = headerAt;
        skipped = true;
        break;
      }
      if (!skipped) return i;
    }
  }

  static String _fit(String text, int width) {
    if (text.length <= width) return text;
    return text.substring(0, width);
  }
}
