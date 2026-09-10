import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hello_world_app/models/saved_printer.dart';
import 'package:hello_world_app/services/printer_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deleteByAddress removes the matching Bluetooth printer', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PrinterStore();
    await store.upsert(
      SavedPrinter(
        id: 'bt-1',
        name: 'Caja',
        type: PrinterLinkType.bluetooth,
        address: 'AA:BB:CC:DD:EE:FF',
      ),
    );
    await store.upsert(
      SavedPrinter(
        id: 'net-1',
        name: 'Cocina',
        type: PrinterLinkType.network,
        address: '192.168.1.10',
      ),
    );

    final removed = await store.deleteByAddress(
      'aa:bb:cc:dd:ee:ff',
      type: PrinterLinkType.bluetooth,
    );
    expect(removed, ['bt-1']);
    final left = await store.loadAll();
    expect(left.map((p) => p.id), ['net-1']);
  });
}
