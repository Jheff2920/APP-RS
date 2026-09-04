import 'package:image/image.dart' as img;

import '../models/cut_mode.dart';
import 'escpos_gs_v0.dart';

/// Avance de papel y cierre de ticket (margen inferior + corte).
class EscPosFeed {
  /// ~203 dpi → ~8 puntos por mm.
  static const double dotsPerMm = 8;

  /// Franjas blancas GS v 0 (avance fiable tras raster).
  static List<int> tearOff({
    required double mm,
    required int paperDotsWidth,
  }) {
    if (mm <= 0) return const [];

    final out = <int>[];
    final width = paperDotsWidth - (paperDotsWidth % 8);
    if (width < 8) return const [];

    var remaining = (mm * dotsPerMm).round().clamp(1, 800);

    while (remaining > 0) {
      final h = remaining > 96 ? 96 : remaining;
      remaining -= h;
      final blank = img.Image(width: width, height: h, numChannels: 3);
      img.fill(blank, color: img.ColorRgb8(255, 255, 255));
      out.addAll(EscPosGsV0.encode(blank));
    }

    return out;
  }

  /// Cierre de ticket: margen inferior (ajustes) y luego corte.
  static List<int> finishJob({
    required double bottomMm,
    required int paperDotsWidth,
    CutMode cut = CutMode.none,
  }) {
    final out = <int>[];
    if (bottomMm > 0) {
      out.addAll(tearOff(mm: bottomMm, paperDotsWidth: paperDotsWidth));
    }
    if (cut != CutMode.none) {
      out.addAll(cut.escPosBytes);
    }
    return out;
  }
}
