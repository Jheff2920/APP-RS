import 'package:image/image.dart' as img;

import '../models/cut_mode.dart';
import 'escpos_gs_v0.dart';

/// Avance de papel y cierre de ticket (margen inferior + corte).
class EscPosFeed {
  /// ~203 dpi → ~8 puntos por mm.
  static const double dotsPerMm203 = 8;

  /// Franjas blancas GS v 0 (avance fiable tras raster).
  static List<int> tearOff({
    required double mm,
    required int paperDotsWidth,
    double dotsPerMm = dotsPerMm203,
  }) {
    if (mm <= 0) return const [];

    final out = <int>[];
    final width = paperDotsWidth - (paperDotsWidth % 8);
    if (width < 8) return const [];

    var remaining = (mm * dotsPerMm).round().clamp(1, 1200);

    while (remaining > 0) {
      final h = remaining > 96 ? 96 : remaining;
      remaining -= h;
      final blank = img.Image(width: width, height: h, numChannels: 3);
      img.fill(blank, color: img.ColorRgb8(255, 255, 255));
      out.addAll(EscPosGsV0.encode(blank));
    }

    return out;
  }

  /// Cierre de ticket: margen inferior y corte (la gaveta va aparte).
  /// En LAN/803L no uses GS v 0 en blanco: el módulo Ethernet se cuelga.
  static List<int> finishJob({
    required double bottomMm,
    required int paperDotsWidth,
    CutMode cut = CutMode.none,
    double dotsPerMm = dotsPerMm203,
    bool network = false,
  }) {
    if (network) return finishNetwork(bottomMm: bottomMm, cut: cut);
    final out = <int>[];
    if (bottomMm > 0) {
      out.addAll(
        tearOff(
          mm: bottomMm,
          paperDotsWidth: paperDotsWidth,
          dotsPerMm: dotsPerMm,
        ),
      );
    }
    if (cut != CutMode.none) {
      out.addAll(cut.escPosBytes);
    }
    return out;
  }

  /// Avance ESC d + corte GS V 0x00 (la 803L no ejecuta el '0' ASCII).
  static List<int> finishNetwork({
    required double bottomMm,
    required CutMode cut,
  }) {
    final out = <int>[];
    if (bottomMm > 0) {
      final lines = (bottomMm / 3.5).round().clamp(3, 12);
      out.addAll([0x1b, 0x64, lines]);
    }
    if (cut != CutMode.none) {
      out.addAll(
        cut == CutMode.fullGsV0 ? const [0x1d, 0x56, 0x00] : cut.escPosBytes,
      );
    }
    return out;
  }
}
