import '../../models/saved_printer.dart';
import '../usb_printer_channel.dart';
import 'printer_transport.dart';

class UsbTransport implements PrinterTransport {
  bool _connected = false;

  @override
  Future<void> connect(SavedPrinter printer) async {
    final address = printer.address.trim();
    if (address.isEmpty) {
      throw PrinterTransportException('Selecciona un dispositivo USB.');
    }
    final ok = await UsbPrinterChannel.requestPermission(address);
    if (!ok) {
      throw PrinterTransportException(
        'Sin permiso USB. Elige de nuevo la impresora en Boleta Print.',
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
