import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../models/paper_width.dart';
import '../models/saved_printer.dart';
import 'escpos_feed.dart';

class EscPosTestPage {
  /// Genera bytes ESC/POS de una pagina de prueba con regla de calibracion.
  static Future<List<int>> build(SavedPrinter printer) async {
    final profile = await CapabilityProfile.load();
    final paperSize =
        printer.paper == PaperWidth.mm58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paperSize, profile);
    final margins = printer.margins;

    final totalCols = printer.paper.charsPerLine;
    final leftPad = _charsForMm(printer.paper, margins.leftMm);
    final rightPad = _charsForMm(printer.paper, margins.rightMm);
    final usable = (totalCols - leftPad - rightPad).clamp(8, totalCols);
    final safeLeft = leftPad.clamp(0, totalCols - usable);
    final paperDots = printer.paper == PaperWidth.mm58 ? 384 : 576;

    List<int> bytes = [];
    bytes += generator.reset();

    void leftLine(String text, {PosStyles styles = const PosStyles()}) {
      final content = _fit(text, usable);
      final line = (' ' * safeLeft) + content;
      bytes += generator.text(line, styles: styles);
    }

    void centerLine(String text, {PosStyles styles = const PosStyles()}) {
      final content = _fit(text, usable);
      bytes += generator.text(
        content,
        styles: PosStyles(
          align: PosAlign.center,
          bold: styles.bold,
          height: styles.height,
          width: styles.width,
          reverse: styles.reverse,
          underline: styles.underline,
          turn90: styles.turn90,
          fontType: styles.fontType,
          codeTable: styles.codeTable,
        ),
      );
    }

    centerLine(
      'BOLETA PRINT',
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    centerLine('Pagina de prueba');
    leftLine('-' * usable);

    final now = DateTime.now();
    leftLine('Impresora: ${printer.name}');
    leftLine('Tipo: ${printer.type.label}');
    leftLine('Dir: ${printer.connectionSummary}');
    leftLine('Papel: ${printer.paper.label}');
    leftLine(
      'Margenes L/R/Inf: '
      '${margins.leftMm.toStringAsFixed(1)}/'
      '${margins.rightMm.toStringAsFixed(1)}/'
      '${margins.bottomMm.toStringAsFixed(1)} mm',
    );
    leftLine('Ancho util: $usable/$totalCols cols');
    leftLine(
      'Fecha: ${now.year}-${_pad2(now.month)}-${_pad2(now.day)} '
      '${_pad2(now.hour)}:${_pad2(now.minute)}:${_pad2(now.second)}',
    );

    leftLine('-' * usable);
    leftLine('REGLA (cada 5 mm ~)', styles: const PosStyles(bold: true));
    for (final rule in _buildRulerLines(usable, printer.paper)) {
      leftLine(rule);
    }

    leftLine('-' * usable);
    leftLine('Texto normal de muestra.');
    leftLine('Texto en negrita.', styles: const PosStyles(bold: true));
    leftLine('Si la regla se corta, sube margenes.');
    leftLine('Borde blanco L/R ~5mm en 58mm es fisico.');
    leftLine('Inf=${margins.bottomMm.toStringAsFixed(0)}mm = avance para cortar.');

    // Margen inferior + corte opcional (RawBT: feed luego cutPaper).
    bytes += EscPosFeed.finishJob(
      bottomMm: margins.bottomMm,
      paperDotsWidth: paperDots,
      cut: printer.cut,
    );
    return bytes;
  }

  static int _charsForMm(PaperWidth paper, double mm) {
    if (mm <= 0) return 0;
    final mmPerChar = paper.printableWidthMm / paper.charsPerLine;
    return (mm / mmPerChar).round().clamp(0, paper.charsPerLine - 8);
  }

  static String _fit(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    if (maxChars <= 1) return text.substring(0, maxChars);
    return '${text.substring(0, maxChars - 1)}~';
  }

  static List<String> _buildRulerLines(int chars, PaperWidth paper) {
    final mmPerChar = paper.printableWidthMm / paper.charsPerLine;
    final step = (5 / mmPerChar).round().clamp(1, 8);

    final marks = StringBuffer();
    for (var i = 0; i < chars; i++) {
      if (i % step == 0) {
        marks.write('|');
      } else if (i % step == step ~/ 2) {
        marks.write('+');
      } else {
        marks.write('-');
      }
    }

    final labels = List.filled(chars, ' ');
    for (var i = 0; i < chars; i++) {
      final mm = (i * mmPerChar).round();
      if (i == 0 || mm % 10 == 0) {
        final label = mm.toString();
        for (var j = 0; j < label.length && i + j < chars; j++) {
          labels[i + j] = label[j];
        }
      }
    }

    final endLabel = chars.toString();
    final scale = StringBuffer('0');
    final midDashes = (chars - 1 - endLabel.length).clamp(0, chars);
    scale.write('-' * midDashes);
    scale.write(endLabel);
    var scaleStr = scale.toString();
    if (scaleStr.length > chars) scaleStr = scaleStr.substring(0, chars);

    return [marks.toString(), labels.join(), scaleStr];
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');
}
