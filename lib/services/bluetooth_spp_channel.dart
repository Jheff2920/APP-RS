import 'package:flutter/services.dart';

import '../platform_caps.dart';

/// RFCOMM nativo: un solo volcado del ticket, sin flush cada 16 KB.
class BluetoothSppChannel {
  static const _ch = MethodChannel('boleta_print/bt_spp');

  static bool get isSupported => PlatformCaps.isAndroid;

  static Future<void> connect(String address) async {
    _requireAndroid();
    await _ch.invokeMethod<void>('connect', {'address': address.trim()});
  }

  static Future<void> write(List<int> bytes) async {
    _requireAndroid();
    await _ch.invokeMethod<void>('write', {
      'bytes': Uint8List.fromList(bytes),
    });
  }

  static Future<void> close() async {
    if (!isSupported) return;
    try {
      await _ch.invokeMethod<void>('close');
    } on MissingPluginException {
      return;
    }
  }

  static void _requireAndroid() {
    if (!isSupported) {
      throw PlatformException(
        code: 'unsupported',
        message: 'Bluetooth SPP nativo solo esta en Android.',
      );
    }
  }
}
