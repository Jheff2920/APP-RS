import 'dart:async';

import 'package:flutter/services.dart';

import '../platform_caps.dart';

/// Archivos abiertos en iOS (Abrir con / “Open in”) copiados a tmp nativo.
class IncomingFiles {
  static const _ch = MethodChannel('boleta_print/incoming_file');
  static StreamController<String>? _controller;
  static bool _bound = false;

  static Stream<String> get stream {
    _ensureBound();
    return _controller!.stream;
  }

  static void _ensureBound() {
    if (_bound) return;
    _bound = true;
    _controller = StreamController<String>.broadcast();
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'opened') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          _controller!.add(path);
        }
      }
    });
  }

  static Future<String?> takePending() async {
    if (!PlatformCaps.isIOS) return null;
    _ensureBound();
    try {
      final path = await _ch.invokeMethod<String>('takePending');
      if (path == null || path.isEmpty) return null;
      return path;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
