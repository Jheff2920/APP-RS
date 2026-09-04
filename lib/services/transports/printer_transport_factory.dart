import '../../models/saved_printer.dart';
import 'bluetooth_transport.dart';
import 'network_transport.dart';
import 'printer_transport.dart';

class PrinterTransportFactory {
  static PrinterTransport create(SavedPrinter printer) {
    switch (printer.type) {
      case PrinterLinkType.bluetooth:
        return BluetoothTransport();
      case PrinterLinkType.network:
        return NetworkTransport();
    }
  }
}

