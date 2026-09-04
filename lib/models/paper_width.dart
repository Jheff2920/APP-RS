enum PaperWidth {
  mm58,
  mm80;

  String get label => this == PaperWidth.mm58 ? '58 mm' : '80 mm';

  int get charsPerLine => this == PaperWidth.mm58 ? 32 : 48;

  /// Ancho aproximado imprimible en mm (sin margenes).
  double get printableWidthMm => this == PaperWidth.mm58 ? 48.0 : 72.0;

  static PaperWidth fromName(String name) {
    return PaperWidth.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PaperWidth.mm58,
    );
  }
}
