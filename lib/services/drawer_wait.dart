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
        // El write BT ya espera a que el RFCOMM trague el ticket (el papel
        // ya salió). 2.5–8 s extra dejaban la gaveta y el círculo colgados.
        return const Duration(milliseconds: 400);
    }
  }
}
