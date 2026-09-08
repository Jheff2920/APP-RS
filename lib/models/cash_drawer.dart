/// Pulso de gaveta ESC/POS (`ESC p m t1 t2`). Opcional: default none.
enum CashDrawer {
  none,
  pin2,
  pin5;

  String get label {
    switch (this) {
      case CashDrawer.none:
        return 'Sin gaveta';
      case CashDrawer.pin2:
        return 'Pin 2 (ESC p 0)';
      case CashDrawer.pin5:
        return 'Pin 5 (ESC p 1)';
    }
  }

  String get hint {
    switch (this) {
      case CashDrawer.none:
        return 'No envía comando (impresoras sin cajón)';
      case CashDrawer.pin2:
        return 'Conector habitual; se abre al terminar de imprimir';
      case CashDrawer.pin5:
        return 'Segundo conector del cajón';
    }
  }

  /// ESC p m t1 t2 — pulso Epson ~50 ms / ~240 ms.
  List<int> get escPosBytes {
    switch (this) {
      case CashDrawer.none:
        return const [];
      case CashDrawer.pin2:
        return const [0x1b, 0x70, 0x00, 0x19, 0x78];
      case CashDrawer.pin5:
        return const [0x1b, 0x70, 0x01, 0x19, 0x78];
    }
  }

  static CashDrawer fromName(String name) {
    return CashDrawer.values.firstWhere(
      (e) => e.name == name,
      orElse: () => CashDrawer.none,
    );
  }
}
