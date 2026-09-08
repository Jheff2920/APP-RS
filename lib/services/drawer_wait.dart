import '../models/saved_printer.dart';

/// Espera a que salga el papel antes de mandar ESC p.
class DrawerWait {
  static Duration forPrinter(SavedPrinter printer, int ticketBytes) {
    switch (printer.type) {
      case PrinterLinkType.network:
        return const Duration(milliseconds: 300);
      case PrinterLinkType.usb:
        return const Duration(milliseconds: 800);
      case PrinterLinkType.bluetooth:
        final ms = (ticketBytes / 3).round().clamp(2500, 8000);
        return Duration(milliseconds: ms);
    }
  }
}
