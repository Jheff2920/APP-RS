import 'dart:async';
import 'package:flutter/services.dart';
import '../platform_caps.dart';
import 'transports/printer_transport_factory.dart';

class PrintJobCoordinator {
  static const _channel = MethodChannel('boleta_print/printers_prefs');
  static Future<void>? _tail;

  static Future<T> run<T>(Future<T> Function() job) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    if (previous != null) await previous;
    String? lease;
    try {
      if (PlatformCaps.isAndroid &&
          !PrinterTransportFactory.usesTestTransport) {
        lease = await _channel.invokeMethod<String>('acquirePrintJob');
        if (lease == null) {
          throw StateError('No se pudo reservar la impresora.');
        }
      }
      return await job();
    } finally {
      try {
        if (lease != null) {
          await _channel.invokeMethod<void>('releasePrintJob', lease);
        }
      } finally {
        done.complete();
        if (identical(_tail, done.future)) _tail = null;
      }
    }
  }
}
