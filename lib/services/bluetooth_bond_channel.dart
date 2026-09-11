import 'dart:async';

import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

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
}

class BluetoothBondException implements Exception {
  BluetoothBondException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
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
        'El emparejado desde la app solo está en Android.',
      );
    }
    try {
      final ok = await _ch.invokeMethod<bool>('createBond', {
        'address': address,
      });
      if (ok != true) {
        throw BluetoothBondException('bond_failed', 'No se pudo emparejar');
      }
    } on MissingPluginException {
      throw BluetoothBondException(
        'unsupported',
        'El emparejado Bluetooth no está disponible.',
      );
    } on PlatformException catch (e) {
      throw BluetoothBondException(e.code, e.message ?? e.code);
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
          'No se pudo desvincular del Bluetooth',
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
