import 'dart:io';
import 'dart:typed_data';

import '../../models/saved_printer.dart';
import 'printer_transport.dart';

class NetworkTransport implements PrinterTransport {
  Socket? _socket;

  @override
  Future<void> connect(SavedPrinter printer) async {
    final host = printer.address.trim();
    final port = printer.port;
    try {
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 8),
      );
    } on SocketException catch (e) {
      throw PrinterTransportException(
        'No se pudo conectar a $host:$port. ${e.message}',
      );
    } on Exception catch (e) {
      throw PrinterTransportException('Error de red: $e');
    }
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    final socket = _socket;
    if (socket == null) {
      throw PrinterTransportException('No hay conexion WiFi/TCP activa.');
    }

    const chunkSize = 8192;
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      socket.add(Uint8List.fromList(bytes.sublist(i, end)));
      await socket.flush();
    }
  }

  @override
  Future<void> disconnect() async {
    await _socket?.flush();
    await _socket?.close();
    _socket = null;
  }
}
