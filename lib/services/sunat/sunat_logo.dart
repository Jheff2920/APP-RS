import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../l10n/app_lang.dart';
import '../escpos_gs_v0.dart';

class SunatLogoException implements Exception {
  SunatLogoException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Logo de empresa para el ticket SUNAT: se guarda chico y se imprime centrado.
class SunatLogo {
  static const maxSourceBytes = 8 * 1024 * 1024;
  static const maxStoredBytes = 400000;
  static const storedMaxWidth = 576;
  static const storedMaxHeight = 220;

  /// Tinta por debajo de este gris. El fondo blanco del logo no se imprime.
  static const inkThreshold = 200;

  static Uint8List preparePng(Uint8List raw) {
    if (raw.isEmpty) {
      throw SunatLogoException(
        tr('La imagen está vacía.', 'The image is empty.'),
      );
    }
    if (raw.length > maxSourceBytes) {
      throw SunatLogoException(
        tr(
          'La imagen es demasiado grande. Usa un PNG o JPG de menos de 8 MB.',
          'The image is too large. Use a PNG or JPG under 8 MB.',
        ),
      );
    }
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw SunatLogoException(
        tr(
          'No se pudo leer la imagen. Usa PNG o JPG.',
          'Could not read the image. Use PNG or JPG.',
        ),
      );
    }
    final fitted = _fit(decoded, storedMaxWidth, storedMaxHeight);
    final flat = flattenOnWhite(fitted);
    var encoded = Uint8List.fromList(img.encodePng(flat));
    if (encoded.length > 350000) {
      encoded = Uint8List.fromList(img.encodeJpg(flat, quality: 75));
    }
    if (encoded.length > maxStoredBytes) {
      throw SunatLogoException(
        tr(
          'La imagen sigue siendo muy grande después de reducirla.',
          'The image is still too large after resizing.',
        ),
      );
    }
    return encoded;
  }

  /// Raster `GS v 0` centrado en el ancho del rollo. Vacío si no se puede leer.
  static List<int> rasterForPaper(
    Uint8List bytes, {
    required int dotsWidth,
  }) {
    if (bytes.isEmpty || dotsWidth < 16) return const [];
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width < 1 || decoded.height < 1) {
      return const [];
    }
    final width = dotsWidth - (dotsWidth % 8);
    final flat = flattenOnWhite(decoded);
    final targetW = (width * 0.70).round().clamp(48, width);
    var sized = _fit(flat, targetW, 200);
    if (sized.width > width) {
      sized = _fit(sized, width, 200);
    }
    final pad = ((width - sized.width) / 2).floor().clamp(0, width - 1);
    return EscPosGsV0.encodeLuminance(
      sized,
      threshold: inkThreshold,
      outputWidth: width,
      leftPad: pad,
    );
  }

  /// El PNG con transparencia se aplana sobre blanco para no imprimir un bloque negro.
  static img.Image flattenOnWhite(img.Image src) {
    final out = img.Image(width: src.width, height: src.height, numChannels: 3);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final a = (p.a.toDouble() / 255).clamp(0.0, 1.0);
        final r = (p.r * a + 255 * (1 - a)).round().clamp(0, 255);
        final g = (p.g * a + 255 * (1 - a)).round().clamp(0, 255);
        final b = (p.b * a + 255 * (1 - a)).round().clamp(0, 255);
        out.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }
    return out;
  }

  static img.Image _fit(img.Image src, int maxWidth, int maxHeight) {
    if (src.width < 1 || src.height < 1) return src;
    if (src.width <= maxWidth && src.height <= maxHeight) return src;
    final scale = math.min(maxWidth / src.width, maxHeight / src.height);
    final w = math.max(1, (src.width * scale).round());
    final h = math.max(1, (src.height * scale).round());
    return img.copyResize(
      src,
      width: w,
      height: h,
      interpolation: img.Interpolation.average,
    );
  }
}
