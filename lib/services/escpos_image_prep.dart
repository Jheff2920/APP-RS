import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Recorte de voucher en capturas (Yape/Plin): el recuadro claro, no el fondo.
class EscPosImagePrep {
  /// Piso para logos naranja/morado. Tope para no pintar el gris claro de BCP
  /// (pastilla, greca) como tinta: esas capturas son ~97 % papel y el promedio
  /// del gris subiría a ~250.
  static const sharedMinThreshold = 168;
  static const sharedMaxThreshold = 200;

  /// Promedio del gris (0.25R+0.5G+0.25B), tope 254. Mismo criterio que
  /// el filtro 0 de las térmicas de referencia.
  static int thresholdFor(
    img.Image work, {
    int minThreshold = 0,
    int maxThreshold = 254,
  }) {
    var sum = 0;
    var n = 0;
    for (var y = 0; y < work.height; y++) {
      for (var x = 0; x < work.width; x++) {
        final p = work.getPixel(x, y);
        var g = (p.r.toInt() >> 2) + (p.g.toInt() >> 1) + (p.b.toInt() >> 2);
        if (g > 249) g = 255;
        sum += g;
        n++;
      }
    }
    if (n == 0) return 254;
    var value = sum ~/ n;
    if (value < minThreshold) value = minThreshold;
    if (value > maxThreshold) value = maxThreshold;
    return value > 254 ? 254 : value;
  }

  static img.Image cropVoucher(img.Image work) {
    final w = work.width;
    final h = work.height;
    if (w < 48 || h < 48) return work;

    final stepX = w > 900 ? 2 : 1;
    final stepY = h > 1600 ? 2 : 1;
    final paper = List<bool>.filled(h, false);
    for (var y = 0; y < h; y += stepY) {
      var bright = 0;
      var samples = 0;
      for (var x = 0; x < w; x += stepX) {
        final p = work.getPixel(x, y);
        samples++;
        if (p.r.toInt() + p.g.toInt() + p.b.toInt() >= 540) bright++;
      }
      final isPaper = samples > 0 && bright * 2 >= samples;
      for (var yy = y; yy < y + stepY && yy < h; yy++) {
        paper[yy] = isPaper;
      }
    }

    final maxGap = math.max(24, h ~/ 16);
    var bestTop = -1;
    var bestBottom = -1;
    var bestLen = -1;
    var runTop = -1;
    var gap = 0;
    for (var y = 0; y < h; y++) {
      if (paper[y]) {
        if (runTop < 0) runTop = y;
        gap = 0;
      } else if (runTop >= 0) {
        gap++;
        if (gap > maxGap) {
          final bottom = y - gap - 1;
          final len = bottom - runTop + 1;
          if (len > bestLen) {
            bestLen = len;
            bestTop = runTop;
            bestBottom = bottom;
          }
          runTop = -1;
          gap = 0;
        }
      }
    }
    if (runTop >= 0) {
      final bottom = h - 1;
      final len = bottom - runTop + 1;
      if (len > bestLen) {
        bestLen = len;
        bestTop = runTop;
        bestBottom = bottom;
      }
    }
    if (bestTop < 0 || bestLen < math.max(48, h ~/ 8)) {
      return work;
    }

    var left = -1;
    var right = -1;
    final span = bestBottom - bestTop + 1;
    for (var x = 0; x < w; x++) {
      var content = 0;
      for (var y = bestTop; y <= bestBottom; y += stepY) {
        final p = work.getPixel(x, y);
        final sum = p.r.toInt() + p.g.toInt() + p.b.toInt();
        if (sum >= 540 || sum <= 270) content++;
      }
      if (content * stepY * 6 >= span) {
        if (left < 0) left = x;
        right = x;
      }
    }
    if (left < 0 || right - left + 1 < 32) return work;

    final padX = math.max(2, (right - left) ~/ 40);
    final padY = math.max(2, bestLen ~/ 50);
    left = math.max(0, left - padX);
    right = math.min(w - 1, right + padX);
    bestTop = math.max(0, bestTop - padY);
    bestBottom = math.min(h - 1, bestBottom + padY);
    final cw = right - left + 1;
    final ch = bestBottom - bestTop + 1;
    if (cw < 32 || ch < 32) return work;
    return img.copyCrop(work, x: left, y: bestTop, width: cw, height: ch);
  }
}
