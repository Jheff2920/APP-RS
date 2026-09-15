import '../../l10n/app_lang.dart';
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
        tr(
          'USB solo está disponible en Android (impresora integrada IMIN/Falcon). '
          'En iPhone/iPad usa WiFi (TCP 9100).',
          'USB is only available on Android (built-in IMIN/Falcon printer). '
          'On iPhone/iPad use WiFi (TCP 9100).',
        ),
      );
    }
    final address = printer.address.trim();
    if (address.isEmpty) {
      throw PrinterTransportException(
        tr('Selecciona un dispositivo USB.', 'Select a USB device.'),
      );
    }
    final ok = await UsbPrinterChannel.requestPermission(address);
    if (!ok) {
      throw PrinterTransportException(
        tr(
          'Sin permiso USB. Tras encender el equipo acepta el aviso de USB.',
          'USB permission denied. After powering on the device, accept the USB prompt.',
        ),
      );
    }
    try {
      await UsbPrinterChannel.open(address);
    } catch (e) {
      throw PrinterTransportException(
        tr(
          'No se pudo conectar por USB. Reconecta el cable o vuelve a dar permiso.',
          'Could not connect over USB. Reconnect the cable or grant permission again.',
        ),
      );
    }
    _connected = true;
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    if (!_connected) {
      throw PrinterTransportException(
        tr('No hay conexion USB activa.', 'There is no active USB connection.'),
      );
    }
    try {
      await UsbPrinterChannel.write(bytes);
    } catch (e) {
      throw PrinterTransportException(
        tr(
          'No se pudo enviar la impresión por USB. Reconecta el cable e inténtalo de nuevo.',
          'Could not send the print job over USB. Reconnect the cable and try again.',
        ),
      );
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
