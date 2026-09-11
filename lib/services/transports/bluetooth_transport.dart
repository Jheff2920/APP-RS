import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../models/saved_printer.dart';
import '../../platform_caps.dart';
import '../bluetooth_spp_channel.dart';
import 'printer_transport.dart';

class BluetoothTransport implements PrinterTransport {
  /// La 803B tira los primeros bytes del write. Si ahí va ESC @, imprime "@".
  /// Los ceros se pierden sin marcar el papel; el ticket sigue pegado.
  static final _leadIn = List<int>.filled(128, 0x00);

  bool _connected = false;
  bool _needsWake = false;
  bool _nativeSpp = false;

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
    try {
      await BluetoothSppChannel.close();
    } catch (_) {}

    if (BluetoothSppChannel.isSupported) {
      try {
        await BluetoothSppChannel.connect(printer.address.trim());
      } catch (e) {
        throw PrinterTransportException(
          'No se pudo conectar por Bluetooth a ${printer.address}. '
          'Empareja la impresora en Ajustes de Android primero. ($e)',
        );
      }
      _nativeSpp = true;
      _connected = true;
      _needsWake = true;
      return;
    }

    final ok = await PrintBluetoothThermal.connect(
      macPrinterAddress: printer.address.trim(),
    );
    if (!ok) {
      throw PrinterTransportException(
        'No se pudo conectar por Bluetooth a ${printer.address}. '
        '${PlatformCaps.isIOS ? 'En iPhone/iPad el Bluetooth Classic de impresoras genéricas no está disponible. Usa WiFi (IP y puerto 9100) o una impresora BLE/MFi.' : 'Empareja la impresora en Ajustes de Android primero.'}',
      );
    }
    _nativeSpp = false;
    _connected = true;
    _needsWake = true;
    await Future<void>.delayed(const Duration(milliseconds: 280));
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    if (!_connected) {
      throw PrinterTransportException('No hay conexion Bluetooth activa.');
    }

    if (_nativeSpp) {
      try {
        await BluetoothSppChannel.write(bytes);
      } catch (e) {
        throw PrinterTransportException(
          'Fallo al enviar datos a la impresora Bluetooth. ($e)',
        );
      }
      _needsWake = false;
      return;
    }

    var payload = bytes;
    if (_needsWake) {
      _needsWake = false;
      payload = <int>[..._leadIn, ...bytes];
    }

    final ok = await PrintBluetoothThermal.writeBytes(payload);
    if (!ok) {
      throw PrinterTransportException(
        'Fallo al enviar datos a la impresora Bluetooth.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    try {
      if (_nativeSpp) {
        await BluetoothSppChannel.close();
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 220));
        await PrintBluetoothThermal.disconnect;
      }
    } finally {
      _connected = false;
      _needsWake = false;
      _nativeSpp = false;
    }
  }

  static Future<List<BluetoothInfo>> pairedDevices() {
    return PrintBluetoothThermal.pairedBluetooths;
  }
}
