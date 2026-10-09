import 'package:flutter/foundation.dart';

import '../../models/saved_printer.dart';
import 'bluetooth_transport.dart';
import 'network_transport.dart';
import 'printer_transport.dart';
import 'usb_transport.dart';

class PrinterTransportFactory {
  /// Solo pruebas: sustituye el transporte real por uno falso, para recorrer
  /// los flujos de impresión sin impresora.
  @visibleForTesting
  static PrinterTransport Function(SavedPrinter printer)? testOverride;

  static PrinterTransport create(SavedPrinter printer) {
    final override = testOverride;
    if (override != null) return override(printer);
    switch (printer.type) {
      case PrinterLinkType.bluetooth:
        return BluetoothTransport();
      case PrinterLinkType.network:
        return NetworkTransport();
      case PrinterLinkType.usb:
        return UsbTransport();
    }
  }
}
