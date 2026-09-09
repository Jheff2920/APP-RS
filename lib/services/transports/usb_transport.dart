import '../../models/saved_printer.dart';
import '../../platform_caps.dart';
import '../usb_printer_channel.dart';
import 'printer_transport.dart';

class UsbTransport implements PrinterTransport {
  bool _connected = false;

  @override
  Future<void> connect(SavedPrinter printer) async {
    if (!PlatformCaps.supportsUsb) {
      throw PrinterTransportException(
        'USB solo está disponible en Android (impresora integrada IMIN/Falcon). '
        'En iPhone/iPad usa WiFi (TCP 9100).',
      );
    }
    final address = printer.address.trim();
    if (address.isEmpty) {
      throw PrinterTransportException('Selecciona un dispositivo USB.');
    }
    final ok = await UsbPrinterChannel.requestPermission(address);
    if (!ok) {
      throw PrinterTransportException(
        'Sin permiso USB. Tras encender el equipo acepta el aviso de USB.',
      );
    }
    try {
      await UsbPrinterChannel.open(address);
    } catch (e) {
      throw PrinterTransportException('No se pudo abrir USB: $e');
    }
    _connected = true;
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    if (!_connected) {
      throw PrinterTransportException('No hay conexion USB activa.');
    }
    try {
      await UsbPrinterChannel.write(bytes);
    } catch (e) {
      throw PrinterTransportException('Fallo USB: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    try {
      await UsbPrinterChannel.close();
    } catch (_) {}
  }
}
