import 'package:permission_handler/permission_handler.dart';

class PrinterPermissions {
  static Future<bool> ensureBluetooth() async {
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

    return connectOk && scanOk;
  }

  /// Android 10+: el PrintService necesita overlay (o notificación) para abrir la app.
  static Future<bool> ensureSystemOverlay() async {
    final status = await Permission.systemAlertWindow.status;
    if (status.isGranted) return true;
    final next = await Permission.systemAlertWindow.request();
    if (next.isGranted) return true;
    return openAppSettings();
  }

  static Future<bool> hasSystemOverlay() async {
    return Permission.systemAlertWindow.isGranted;
  }
}
