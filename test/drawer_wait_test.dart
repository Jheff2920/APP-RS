import 'package:flutter_test/flutter_test.dart';
import 'package:hello_world_app/models/saved_printer.dart';
import 'package:hello_world_app/services/drawer_wait.dart';

void main() {
  SavedPrinter printer(PrinterLinkType type) {
    return SavedPrinter(
      id: 'p',
      name: 'Caja',
      type: type,
      address: 'AA:BB:CC:DD:EE:FF',
    );
  }

  test('Bluetooth drawer wait stays short after a blocking write', () {
    expect(
      DrawerWait.forPrinter(printer(PrinterLinkType.bluetooth), 120000),
      const Duration(milliseconds: 400),
    );
  });

  test('USB and network waits stay as before', () {
    expect(
      DrawerWait.forPrinter(printer(PrinterLinkType.usb), 120000),
      const Duration(milliseconds: 800),
    );
    expect(
      DrawerWait.forPrinter(printer(PrinterLinkType.network), 120000),
      const Duration(milliseconds: 300),
    );
  });
}
