/// Nitidez: dibuja el PDF mas grande y lo baja al ancho del rollo.
enum RasterScale {
  x1,
  x2,
  x3;

  String get label {
    switch (this) {
      case RasterScale.x1:
        return 'x1 (rapido)';
      case RasterScale.x2:
        return 'x2 (nitido)';
      case RasterScale.x3:
        return 'x3 (maximo)';
    }
  }

  String get hint {
    switch (this) {
      case RasterScale.x1:
        return 'Igual que RawBT; el mas rapido';
      case RasterScale.x2:
        return 'Dibuja al doble y procesa cada punto. Tarda 2–4 s';
      case RasterScale.x3:
        return 'Dibuja al triple. Tarda mas; maxima nitidez';
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
