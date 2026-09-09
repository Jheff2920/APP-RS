import 'dart:io';

import 'package:flutter/services.dart';

/// Copia el URI de Compartir/Abrir a cache de la app (legible en Android 10+).
class SharedIncoming {
  static const _channel = MethodChannel('boleta_print/system_print_ui');

  static Future<String?> copyFromIntent() async {
    if (!Platform.isAndroid) return null;
    try {
      final path = await _channel.invokeMethod<String>('copyFromIntent');
      if (path == null || path.isEmpty) return null;
      final file = File(path);
      if (!await file.exists()) return null;
      if (await file.length() <= 0) return null;
      return path;
    } on PlatformException {
      return null;
    }
  }

  static Future<bool> isReadable(String path) async {
    if (path.isEmpty) return false;
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      if (await file.length() <= 0) return false;
      final raf = await file.open();
      try {
        await raf.read(1);
      } finally {
        await raf.close();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
