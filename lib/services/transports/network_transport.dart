import 'dart:io';
import 'dart:typed_data';

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
      throw PrinterTransportException('No hay conexion WiFi/TCP activa.');
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
        'No se pudo conectar a ${printer.address}:${printer.port}. ${e.message}',
      );
    } on Exception catch (e) {
      throw PrinterTransportException('Error de red: $e');
    }
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    final socket = await _open();
    try {
      socket.add(Uint8List.fromList(bytes));
      await socket.flush();
    } on SocketException catch (e) {
      await _drop();
      throw PrinterTransportException(
        'Se cortó la conexión WiFi/TCP. ${e.message}',
      );
    } on Exception catch (e) {
      await _drop();
      throw PrinterTransportException('Error de red al enviar: $e');
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
