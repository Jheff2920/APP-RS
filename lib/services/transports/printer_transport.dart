import '../../models/saved_printer.dart';

abstract class PrinterTransport {
  Future<void> connect(SavedPrinter printer);

  Future<void> writeBytes(List<int> bytes);

  Future<void> disconnect();
}

class PrinterTransportException implements Exception {
  PrinterTransportException(this.message);
  final String message;

  @override
  String toString() => message;
}
