import 'package:flutter/services.dart';

import '../l10n/app_lang.dart';
import '../platform_caps.dart';

/// TCP :9100 nativo (mismo socket que PrintService/Chrome).
class NetworkLanChannel {
  static const _ch = MethodChannel('boleta_print/lan_tcp');

  static bool get isSupported => PlatformCaps.isAndroid;

  static Future<void> connect(String host, int port) async {
    _requireAndroid();
    await _ch.invokeMethod<void>('connect', {
      'host': host.trim(),
      'port': port,
    });
  }

  static Future<void> write(List<int> bytes) async {
    _requireAndroid();
    await _ch.invokeMethod<void>('write', {
      'bytes': Uint8List.fromList(bytes),
    });
  }

  /// Mismo raster nativo que Chrome/PrintService (fuera del hilo de la UI).
  static Future<List<int>> rasterizePdf({
    required String filePath,
    required String paper,
    required double bottomMm,
    required String cut,
    required int dpi,
    required int rasterScale,
  }) async {
    _requireAndroid();
    final raw = await _ch.invokeMethod<Uint8List>('rasterizePdf', {
      'path': filePath,
      'paper': paper,
      'bottomMm': bottomMm,
      'cut': cut,
      'dpi': dpi,
      'rasterScale': rasterScale,
    });
    if (raw == null || raw.isEmpty) {
      throw PlatformException(
        code: 'empty',
        message: tr('Ticket vacio', 'Empty ticket'),
      );
    }
    return raw;
  }

  static void _requireAndroid() {
    if (!isSupported) {
      throw PlatformException(
        code: 'unsupported',
        message: tr(
          'El socket LAN nativo solo esta en Android.',
          'Native LAN sockets are Android only.',
        ),
      );
    }
  }
}
