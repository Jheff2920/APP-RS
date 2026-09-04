import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Raster ESC/POS `GS v 0`.
///
/// Franjas altas → pocos comandos → el BT envía casi de corrido.
class EscPosGsV0 {
  /// Una sola franja si el ticket cabe; si no, bloques grandes.
  static const int bandHeight = 512;

  /// [image] debe ser blanco/negro (oscuro = tinta) y ancho múltiplo de 8.
  static List<int> encode(img.Image image) {
    final width = image.width - (image.width % 8);
    if (width < 8 || image.height < 1) return [];

    final bytesPerRow = width >> 3;
    final out = <int>[];

    // Preferir un solo GS v 0 para tickets cortos (boleta típica).
    final band = image.height <= bandHeight ? image.height : bandHeight;

    var y = 0;
    while (y < image.height) {
      final rows = math.min(band, image.height - y);
      final payload = List<int>.filled(rows * bytesPerRow, 0);
      var pi = 0;

      for (var row = 0; row < rows; row++) {
        final yy = y + row;
        for (var x = 0; x < width; x += 8) {
          var packed = 0;
          for (var bit = 0; bit < 8; bit++) {
            final p = image.getPixel(x + bit, yy);
            // Ya viene umbralizado: canal R basta.
            if (p.r < 128) {
              packed |= 0x80 >> bit;
            }
          }
          payload[pi++] = packed;
        }
      }

      out.addAll([
        0x1d,
        0x76,
        0x30,
        0x00,
        bytesPerRow & 0xff,
        (bytesPerRow >> 8) & 0xff,
        rows & 0xff,
        (rows >> 8) & 0xff,
      ]);
      out.addAll(payload);
      y += rows;
    }

    return out;
  }

  /// Umbraliza y empaqueta directamente, sin crear otra imagen B/N.
  ///
  /// [image] contiene solo el ancho útil. [leftPad] la ubica dentro de
  /// [outputWidth], lo que evita construir un lienzo completo con márgenes.
  static List<int> encodeLuminance(
    img.Image image, {
    required int threshold,
    required int outputWidth,
    int leftPad = 0,
    bool trimVertical = true,
  }) {
    final width = outputWidth - (outputWidth % 8);
    if (width < 8 || image.height < 1 || leftPad < 0 || leftPad >= width) {
      return [];
    }
    final contentWidth = math.min(image.width, width - leftPad);
    if (contentWidth < 1) return [];

    var top = 0;
    var bottom = image.height - 1;
    if (trimVertical) {
      while (top < image.height &&
          !_rowHasInk(image, top, contentWidth, threshold)) {
        top++;
      }
      while (
          bottom > top && !_rowHasInk(image, bottom, contentWidth, threshold)) {
        bottom--;
      }

      // Conserva el comportamiento anterior para imágenes vacías o trazos
      // extremadamente bajos: no recortar a menos de 8 filas.
      final trimmedHeight = bottom - top + 1;
      if (top >= image.height || trimmedHeight < 8) {
        top = 0;
        bottom = image.height - 1;
      }
    }

    final bytesPerRow = width >> 3;
    final out = <int>[];
    var sourceY = top;
    while (sourceY <= bottom) {
      final rows = math.min(bandHeight, bottom - sourceY + 1);
      final payload = List<int>.filled(rows * bytesPerRow, 0);

      for (var row = 0; row < rows; row++) {
        final y = sourceY + row;
        final rowOffset = row * bytesPerRow;
        for (var x = 0; x < contentWidth; x++) {
          if (_luminance(image.getPixel(x, y)) > threshold) continue;
          final outputX = leftPad + x;
          payload[rowOffset + (outputX >> 3)] |= 0x80 >> (outputX & 7);
        }
      }

      out.addAll([
        0x1d,
        0x76,
        0x30,
        0x00,
        bytesPerRow & 0xff,
        (bytesPerRow >> 8) & 0xff,
        rows & 0xff,
        (rows >> 8) & 0xff,
      ]);
      out.addAll(payload);
      sourceY += rows;
    }
    return out;
  }

  static bool _rowHasInk(
    img.Image image,
    int y,
    int width,
    int threshold,
  ) {
    for (var x = 0; x < width; x++) {
      if (_luminance(image.getPixel(x, y)) <= threshold) return true;
    }
    return false;
  }

  static int _luminance(img.Pixel pixel) {
    return (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).round();
  }
}
