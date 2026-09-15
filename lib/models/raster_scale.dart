import '../l10n/app_lang.dart';

/// Nitidez: dibuja el PDF mas grande y lo baja al ancho del rollo.
enum RasterScale {
  x1,
  x2,
  x3;

  String get label {
    switch (this) {
      case RasterScale.x1:
        return 'x1';
      case RasterScale.x2:
        return 'x2';
      case RasterScale.x3:
        return 'x3';
    }
  }

  String get hint {
    switch (this) {
      case RasterScale.x1:
        return tr('Más rápido', 'Fastest');
      case RasterScale.x2:
        return tr('Más nítido', 'Sharper');
      case RasterScale.x3:
        return tr('Máxima nitidez', 'Maximum sharpness');
    }
  }

  String get detail {
    switch (this) {
      case RasterScale.x1:
        return tr(
          'Calidad normal. Sale antes, sobre todo por Bluetooth.',
          'Normal quality. Finishes sooner, especially over Bluetooth.',
        );
      case RasterScale.x2:
        return tr(
          'Más nítido, mismo tamaño de ticket. Tarda un poco más; en Bluetooth se nota.',
          'Sharper, same ticket size. A bit slower; more noticeable over Bluetooth.',
        );
      case RasterScale.x3:
        return tr(
          'Máxima nitidez, mismo tamaño. Es el más lento, sobre todo por Bluetooth.',
          'Maximum sharpness, same size. Slowest, especially over Bluetooth.',
        );
    }
  }

  int get factor {
    switch (this) {
      case RasterScale.x1:
        return 1;
      case RasterScale.x2:
        return 2;
      case RasterScale.x3:
        return 3;
    }
  }

  static RasterScale fromName(String name) {
    return RasterScale.values.firstWhere(
      (e) => e.name == name,
      orElse: () => RasterScale.x1,
    );
  }
}
