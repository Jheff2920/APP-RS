import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../models/saved_printer.dart';
import 'printer_transport.dart';

class BluetoothTransport implements PrinterTransport {
  bool _connected = false;

  @override
  Future<void> connect(SavedPrinter printer) async {
    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      throw PrinterTransportException(
        'Bluetooth esta apagado. Activalo e intenta de nuevo.',
      );
    }

    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}

    final ok = await PrintBluetoothThermal.connect(
      macPrinterAddress: printer.address.trim(),
    );
    if (!ok) {
      throw PrinterTransportException(
        'No se pudo conectar por Bluetooth a ${printer.address}. '
        'Empareja la impresora en Ajustes de Android primero.',
      );
    }
    _connected = true;
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    if (!_connected) {
      throw PrinterTransportException('No hay conexion Bluetooth activa.');
    }

    // Intento en bloque único → la impresora recibe el job de corrido.
    if (bytes.length <= 49152) {
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (ok) return;
      // Si el plugin rechaza el bloque, caer a chunks.
    }

    var i = 0;
    while (i < bytes.length) {
      final end = _nextWriteEnd(bytes, i);
      final ok = await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end));
      if (!ok) {
        throw PrinterTransportException(
          'Fallo al enviar datos a la impresora Bluetooth (offset $i).',
        );
      }
      i = end;
    }
  }

  static int _nextWriteEnd(List<int> bytes, int start) {
    const maxBytes = 24576;
    if (start + 7 < bytes.length &&
        bytes[start] == 0x1d &&
        bytes[start + 1] == 0x76 &&
        bytes[start + 2] == 0x30) {
      final widthBytes = bytes[start + 4] + (bytes[start + 5] << 8);
      final height = bytes[start + 6] + (bytes[start + 7] << 8);
      final total = 8 + widthBytes * height;
      var end = start + total;
      if (total <= 0 || end > bytes.length) {
        return (start + maxBytes).clamp(start + 1, bytes.length);
      }
      while (end + 7 < bytes.length && end - start < maxBytes) {
        if (bytes[end] != 0x1d ||
            bytes[end + 1] != 0x76 ||
            bytes[end + 2] != 0x30) {
          break;
        }
        final wb = bytes[end + 4] + (bytes[end + 5] << 8);
        final h = bytes[end + 6] + (bytes[end + 7] << 8);
        final t = 8 + wb * h;
        if (t <= 0 || end + t > bytes.length) break;
        if ((end + t) - start > maxBytes) break;
        end += t;
      }
      return end;
    }

    final limit =
        (start + maxBytes < bytes.length) ? start + maxBytes : bytes.length;
    for (var j = start + 1; j < limit - 7; j++) {
      if (bytes[j] == 0x1d && bytes[j + 1] == 0x76 && bytes[j + 2] == 0x30) {
        return j;
      }
    }
    return limit;
  }

  @override
  Future<void> disconnect() async {
    if (_connected) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await PrintBluetoothThermal.disconnect;
      _connected = false;
    }
  }

  static Future<List<BluetoothInfo>> pairedDevices() {
    return PrintBluetoothThermal.pairedBluetooths;
  }
}
