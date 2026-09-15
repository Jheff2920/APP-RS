import 'dart:async';

import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../l10n/app_lang.dart';
import '../platform_caps.dart';
import 'bluetooth_spp_channel.dart';

class NearbyBtDevice {
  const NearbyBtDevice({
    required this.name,
    required this.address,
    required this.bonded,
  });

  final String name;
  final String address;
  final bool bonded;

  String get key => address.toUpperCase();

  /// Classic discovery lists unnamed radios as the MAC. Hide those.
  bool get hasVisibleName {
    final n = name.trim();
    if (n.isEmpty) return false;
    final mac = address.trim().toUpperCase();
    if (n.toUpperCase() == mac) return false;
    final compact = n.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    final macCompact = mac.replaceAll(RegExp(r'[^0-9A-F]'), '');
    if (compact.length >= 12 && compact == macCompact) return false;
    return !RegExp(
      r'^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$',
    ).hasMatch(n);
  }
}

class BluetoothBondException implements Exception {
  BluetoothBondException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => localizedMessage;

  String get localizedMessage {
    switch (code) {
      case 'permission':
        return tr(
          'Faltan permisos de Bluetooth',
          'Bluetooth permission is required',
        );
      case 'need_location':
        return tr(
          'Para buscar impresoras cercanas hay que permitir ubicación (Android la usa en el Bluetooth Classic).',
          'Allow location to scan nearby printers (Android uses it for Classic Bluetooth).',
        );
      case 'location_off':
        return tr(
          'Activa la ubicación del teléfono (no el GPS de mapas: el interruptor de Ubicación). Sin eso Android no lista Bluetooth cercanos.',
          'Turn on Location on the phone (the Location switch, not Maps GPS). Android will not list nearby Classic Bluetooth without it.',
        );
      case 'rejected':
      case 'timeout':
      case 'bond_failed':
        return tr(
          'No se emparejó. Si pide PIN, prueba 0000 o 1234.',
          'Pairing failed. If it asks for a PIN, try 0000 or 1234.',
        );
      case 'off':
        return tr(
          'Bluetooth está apagado. Actívalo e inténtalo de nuevo.',
          'Bluetooth is off. Turn it on and try again.',
        );
      case 'busy':
        return tr(
          'Ya hay un emparejado en curso. Espera un momento.',
          'Pairing is already in progress. Wait a moment.',
        );
      default:
        return tr(
          'No se pudo emparejar. Enciende la impresora e inténtalo de nuevo.',
          'Could not pair. Turn the printer on and try again.',
        );
    }
  }
}

/// Discovery Classic + emparejado del sistema. Solo Android.
class BluetoothBondChannel {
  static const _ch = MethodChannel('boleta_print/bt_bond');
  static const _ev = EventChannel('boleta_print/bt_bond_events');

  static StreamSubscription<dynamic>? _nativeSub;
  static final _controller =
      StreamController<Map<String, dynamic>>.broadcast();
  static Completer<void>? _ready;

  static bool get isSupported => PlatformCaps.isAndroid;

  static Stream<Map<String, dynamic>> events() {
    _attach();
    return _controller.stream;
  }

  static void _attach() {
    if (!isSupported || _nativeSub != null) return;
    _ready = Completer<void>();
    _nativeSub = _ev.receiveBroadcastStream().listen(
      (raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        if (map['type'] == 'ready') {
          final ready = _ready;
          if (ready != null && !ready.isCompleted) {
            ready.complete();
          }
          return;
        }
        _controller.add(map);
      },
      onError: (_) {
        _nativeSub = null;
        _ready = null;
      },
    );
  }

  static Future<void> ensureReady() async {
    if (!isSupported) return;
    _attach();
    final ready = _ready;
    if (ready == null || ready.isCompleted) return;
    try {
      await ready.future.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      return;
    }
  }

  static Future<bool> startScan() async {
    if (!isSupported) return false;
    await ensureReady();
    try {
      final ok = await _ch.invokeMethod<bool>('startScan');
      return ok == true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      throw BluetoothBondException(e.code, e.message ?? e.code);
    }
  }

  static Future<void> stopScan() async {
    if (!isSupported) return;
    try {
      await _ch.invokeMethod<void>('stopScan');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<void> openLocationSettings() async {
    if (!isSupported) return;
    try {
      await _ch.invokeMethod<void>('openLocationSettings');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<void> createBond(String address) async {
    if (!isSupported) {
      throw BluetoothBondException(
        'unsupported',
        tr(
          'El emparejado desde la app solo está en Android.',
          'Pairing from the app is Android only.',
        ),
      );
    }
    try {
      final ok = await _ch.invokeMethod<bool>('createBond', {
        'address': address,
      });
      if (ok != true) {
        throw BluetoothBondException(
          'bond_failed',
          tr('No se pudo emparejar', 'Could not pair'),
        );
      }
      if (!await isBonded(address)) {
        throw BluetoothBondException(
          'rejected',
          tr(
            'No se emparejó. Si pide PIN, prueba 0000 o 1234.',
            'Pairing failed. If it asks for a PIN, try 0000 or 1234.',
          ),
        );
      }
    } on MissingPluginException {
      throw BluetoothBondException(
        'unsupported',
        tr(
          'El emparejado Bluetooth no está disponible.',
          'Bluetooth pairing is not available.',
        ),
      );
    } on PlatformException catch (e) {
      throw BluetoothBondException(e.code, e.message ?? e.code);
    }
  }

  static Future<bool> isBonded(String address) async {
    final mac = address.trim();
    if (mac.isEmpty || !isSupported) return false;
    try {
      final ok = await _ch.invokeMethod<bool>('isFullyBonded', {
        'address': mac,
      });
      return ok == true;
    } on MissingPluginException {
      final bonded = await listBonded();
      return bonded.any((d) => d.address.trim().toUpperCase() == mac.toUpperCase());
    } on PlatformException {
      return false;
    }
  }

  static Future<List<NearbyBtDevice>> listBonded() async {
    if (!isSupported) return const [];
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('listBonded');
      return [
        for (final item in raw ?? const [])
          if (item is Map)
            NearbyBtDevice(
              name: (item['name'] as String? ?? '').trim(),
              address: (item['address'] as String? ?? '').trim(),
              bonded: true,
            ),
      ].where((d) => d.address.isNotEmpty).toList();
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e) {
      throw BluetoothBondException(e.code, e.message ?? e.code);
    }
  }

  static Future<void> removeBond(String address) async {
    if (!isSupported) return;
    final mac = address.trim();
    if (mac.isEmpty) return;
    try {
      final ok = await _ch.invokeMethod<bool>('removeBond', {
        'address': mac,
      });
      if (ok != true) {
        throw BluetoothBondException(
          'unbond_failed',
          tr(
            'No se pudo desvincular del Bluetooth',
            'Could not unpair from Bluetooth',
          ),
        );
      }
    } on MissingPluginException {
      return;
    } on PlatformException catch (e) {
      throw BluetoothBondException(e.code, e.message ?? e.code);
    }
  }

  /// Cierra RFCOMM y olvida el vínculo del sistema (Android).
  static Future<void> forget(String address) async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
    try {
      await BluetoothSppChannel.close();
    } catch (_) {}
    await removeBond(address);
  }
}
