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
}
