import 'package:flutter/foundation.dart';

/// Capacidades reales por plataforma. USB, PrintService y GPIO IMIN son Android.
class PlatformCaps {
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// USB host (Falcon/IMIN) y gaveta GPIO.
  static bool get supportsUsb => isAndroid;

  /// Diálogo Imprimir del sistema + overlay.
  static bool get supportsSystemPrint => isAndroid;

  /// Compartir vía `receive_sharing_intent` (SEND/VIEW nativo).
  static bool get usesShareIntent => isAndroid;

  /// En iPhone/iPad el camino fiable es TCP :9100.
  static bool get prefersNetworkDefault => isIOS;
}
