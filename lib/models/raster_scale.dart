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
        return 'Más rápido';
      case RasterScale.x2:
        return 'Misma medida que x1; mas nítido. Tarda un poco';
      case RasterScale.x3:
        return 'Misma medida que x1; maxima nitidez';
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
