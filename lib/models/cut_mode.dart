import '../l10n/app_lang.dart';

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
        return tr('Sin corte', 'No cut');
      case CutMode.fullGsV0:
        return tr('Corte total (GS V 0)', 'Full cut (GS V 0)');
      case CutMode.fullGsVA:
        return tr('Corte total + avance (GS V A)', 'Full cut + feed (GS V A)');
      case CutMode.fullEscI:
        return tr('Corte total (ESC i)', 'Full cut (ESC i)');
      case CutMode.fullEscD0:
        return tr('Avance ESC d 0', 'Feed ESC d 0');
      case CutMode.partialGsV1:
        return tr('Corte parcial (GS V 1)', 'Partial cut (GS V 1)');
      case CutMode.partialGsVB:
        return tr('Corte parcial + avance (GS V B)', 'Partial cut + feed (GS V B)');
      case CutMode.partialEscM:
        return tr('Corte parcial (ESC m)', 'Partial cut (ESC m)');
      case CutMode.partialEscD1:
        return tr('Avance ESC d 1', 'Feed ESC d 1');
    }
  }

  String get hint {
    switch (this) {
      case CutMode.none:
        return tr('Sin cuchilla', 'No cutter');
      case CutMode.fullGsV0:
      case CutMode.fullGsVA:
      case CutMode.fullEscI:
        return tr('Corta el papel por completo', 'Cuts the paper fully');
      case CutMode.partialGsV1:
      case CutMode.partialGsVB:
      case CutMode.partialEscM:
        return tr(
          'Deja un punto sin cortar (fácil de arrancar)',
          'Leaves a tab so the ticket tears off easily',
        );
      case CutMode.fullEscD0:
      case CutMode.partialEscD1:
        return tr('Solo avance', 'Feed only');
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

  static const uiOrder = [
    fullGsV0,
    fullGsVA,
    fullEscI,
    partialGsV1,
    partialGsVB,
    partialEscM,
    fullEscD0,
    partialEscD1,
    none,
  ];

  static CutMode fromName(String name) {
    return CutMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => CutMode.fullGsV0,
    );
  }
}
