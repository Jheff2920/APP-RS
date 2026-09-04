/// Comando de corte ESC/POS (misma tabla que RawBT `cutTypes`).
enum CutMode {
  none,
  fullGsV0,
  fullGsVA,
  fullEscI,
  fullEscD0,
  partialGsV1,
  partialGsVB,
  partialEscM,
  partialEscD1;

  String get label {
    switch (this) {
      case CutMode.none:
        return 'Sin corte';
      case CutMode.fullGsV0:
        return 'Corte total (GS V 0)';
      case CutMode.fullGsVA:
        return 'Corte total + avance (GS V A)';
      case CutMode.fullEscI:
        return 'Corte total (ESC i)';
      case CutMode.fullEscD0:
        return 'Avance ESC d 0';
      case CutMode.partialGsV1:
        return 'Corte parcial (GS V 1)';
      case CutMode.partialGsVB:
        return 'Corte parcial + avance (GS V B)';
      case CutMode.partialEscM:
        return 'Corte parcial (ESC m)';
      case CutMode.partialEscD1:
        return 'Avance ESC d 1';
    }
  }

  String get hint {
    switch (this) {
      case CutMode.none:
        return 'Portátiles sin cuchilla (HL200B, etc.)';
      case CutMode.fullGsV0:
      case CutMode.fullGsVA:
      case CutMode.fullEscI:
        return 'Corta el papel por completo';
      case CutMode.partialGsV1:
      case CutMode.partialGsVB:
      case CutMode.partialEscM:
        return 'Deja un punto sin cortar (fácil de arrancar)';
      case CutMode.fullEscD0:
      case CutMode.partialEscD1:
        return 'Solo avance (algunos perfiles RawBT)';
    }
  }

  /// Bytes ESC/POS (igual que RawBT EscGeneral.cutPaper).
  List<int> get escPosBytes {
    switch (this) {
      case CutMode.none:
        return const [];
      case CutMode.fullGsV0:
        return const [0x1d, 0x56, 0x30]; // GS V '0'
      case CutMode.fullGsVA:
        return const [0x1d, 0x56, 0x41, 0x00]; // GS V A 0
      case CutMode.fullEscI:
        return const [0x1b, 0x69]; // ESC i
      case CutMode.fullEscD0:
        return const [0x1b, 0x64, 0x00]; // ESC d 0
      case CutMode.partialGsV1:
        return const [0x1d, 0x56, 0x31]; // GS V '1'
      case CutMode.partialGsVB:
        return const [0x1d, 0x56, 0x42, 0x00]; // GS V B 0
      case CutMode.partialEscM:
        return const [0x1b, 0x6d]; // ESC m
      case CutMode.partialEscD1:
        return const [0x1b, 0x64, 0x01]; // ESC d 1
    }
  }

  static CutMode fromName(String name) {
    return CutMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => CutMode.none,
    );
  }
}
