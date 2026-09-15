import 'dart:io';
import 'dart:typed_data';

import '../../l10n/app_lang.dart';
import '../../models/saved_printer.dart';
import 'printer_transport.dart';

class NetworkTransport implements PrinterTransport {
  static final _pool = <String, Socket>{};

  SavedPrinter? _printer;
  String? _key;

  static String _makeKey(SavedPrinter printer) =>
      '${printer.address.trim()}:${printer.port}';

  @override
  Future<void> connect(SavedPrinter printer) async {
    _printer = printer;
    _key = _makeKey(printer);
  }

  Future<Socket> _open() async {
    final printer = _printer;
    final key = _key;
    if (printer == null || key == null) {
      throw PrinterTransportException(
        tr(
          'No hay conexion WiFi/TCP activa.',
          'There is no active WiFi/TCP connection.',
        ),
      );
    }
    final existing = _pool[key];
    if (existing != null) {
      return existing;
    }
    try {
      final socket = await Socket.connect(
        printer.address.trim(),
        printer.port,
        timeout: const Duration(seconds: 8),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
      socket.done.then((_) {
        if (_pool[key] == socket) _pool.remove(key);
      }).catchError((_) {
        if (_pool[key] == socket) _pool.remove(key);
      });
      _pool[key] = socket;
      return socket;
    } on SocketException catch (e) {
      throw PrinterTransportException(
        tr(
          'No se pudo conectar por WiFi. Revisa que la impresora esté encendida y la IP sea correcta.',
          'Could not connect over WiFi. Check that the printer is on and the IP is correct.',
        ),
      );
    } on Exception catch (_) {
      throw PrinterTransportException(
        tr(
          'No se pudo conectar por WiFi. Revisa la red e inténtalo de nuevo.',
          'Could not connect over WiFi. Check the network and try again.',
        ),
      );
    }
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    final socket = await _open();
    try {
      socket.add(Uint8List.fromList(bytes));
      await socket.flush();
    } on SocketException catch (_) {
      await _drop();
      throw PrinterTransportException(
        tr(
          'Se cortó la conexión WiFi. Enciende la impresora y vuelve a intentar.',
          'The WiFi connection dropped. Turn the printer on and try again.',
        ),
      );
    } on Exception catch (_) {
      await _drop();
      throw PrinterTransportException(
        tr(
          'No se pudo enviar la impresión por WiFi. Inténtalo de nuevo.',
          'Could not send the print job over WiFi. Try again.',
        ),
      );
    }
  }

  @override
  Future<void> disconnect() async {
    // No cerrar :9100. La 803L se cuelga al recibir FIN/RST.
    _printer = null;
    _key = null;
  }

  Future<void> _drop() async {
    final key = _key;
    if (key == null) return;
    final socket = _pool.remove(key);
    if (socket == null) return;
    try {
      socket.destroy();
    } catch (_) {}
  }
}
