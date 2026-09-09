import 'package:permission_handler/permission_handler.dart';

import '../platform_caps.dart';

class PrinterPermissions {
  static Future<bool> ensureBluetooth({bool forDiscovery = false}) async {
    if (PlatformCaps.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted ||
          status.isLimited ||
          status.isRestricted ||
          status.isProvisional;
    }

    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    final connect = statuses[Permission.bluetoothConnect];
    final scan = statuses[Permission.bluetoothScan];

    // En Android < 12 estos permisos pueden ser notApplicable; location ayuda al scan.
    final connectOk = connect == null ||
        connect.isGranted ||
        connect.isLimited ||
        connect.isRestricted;
    final scanOk =
        scan == null || scan.isGranted || scan.isLimited || scan.isRestricted;

    if (!connectOk || !scanOk) return false;
    if (!forDiscovery) return true;

    final loc = statuses[Permission.locationWhenInUse];
    return loc == null ||
        loc.isGranted ||
        loc.isLimited ||
        loc.isRestricted ||
        loc.isProvisional;
  }

  /// Android 10+: el PrintService necesita overlay (o notificación) para abrir la app.
  static Future<bool> ensureSystemOverlay() async {
    if (!PlatformCaps.supportsSystemPrint) return true;
    final status = await Permission.systemAlertWindow.status;
    if (status.isGranted) return true;
    final next = await Permission.systemAlertWindow.request();
    if (next.isGranted) return true;
    return openAppSettings();
  }

  static Future<bool> hasSystemOverlay() async {
    if (!PlatformCaps.supportsSystemPrint) return true;
    return Permission.systemAlertWindow.isGranted;
  }
}
