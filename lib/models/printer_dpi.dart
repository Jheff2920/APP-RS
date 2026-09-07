import 'paper_width.dart';

/// Densidad del cabezal. 203 es lo habitual; 300 solo si el manual lo indica.
enum PrinterDpi {
  dpi203,
  dpi300;

  int get value => this == PrinterDpi.dpi203 ? 203 : 300;

  String get label => this == PrinterDpi.dpi203 ? '203 dpi' : '300 dpi';

  String get hint {
    switch (this) {
      case PrinterDpi.dpi203:
        return 'Estandar (HL200B, HQ300 203, casi todas)';
      case PrinterDpi.dpi300:
        return 'Cabezal 300 dpi. Si sale partido, vuelve a 203';
    }
  }

  int dotsFor(PaperWidth paper) {
    final raw = switch (this) {
      PrinterDpi.dpi203 => paper == PaperWidth.mm58 ? 384 : 576,
      PrinterDpi.dpi300 => paper == PaperWidth.mm58 ? 576 : 832,
    };
    return raw - (raw % 8);
  }

  double get dotsPerMm => value / 25.4;

  static PrinterDpi fromName(String name) {
    return PrinterDpi.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PrinterDpi.dpi203,
    );
  }
}
