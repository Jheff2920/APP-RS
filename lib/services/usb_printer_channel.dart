import 'dart:typed_data';

import 'package:flutter/services.dart';

class UsbDeviceInfo {
  UsbDeviceInfo({
    required this.name,
    required this.address,
    required this.vendorId,
    required this.productId,
    required this.hasPermission,
  });

  final String name;
  final String address;
  final int vendorId;
  final int productId;
  final bool hasPermission;

  factory UsbDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return UsbDeviceInfo(
      name: map['name'] as String? ?? 'USB',
      address: map['address'] as String? ?? '',
      vendorId: (map['vendorId'] as num?)?.toInt() ?? 0,
      productId: (map['productId'] as num?)?.toInt() ?? 0,
      hasPermission: map['hasPermission'] as bool? ?? false,
    );
  }
}

class UsbPrinterChannel {
  static const _ch = MethodChannel('boleta_print/usb');

  static Future<List<UsbDeviceInfo>> listDevices() async {
    final raw = await _ch.invokeMethod<List<dynamic>>('listDevices');
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map(UsbDeviceInfo.fromMap)
        .toList();
  }

  static Future<bool> requestPermission(String address) async {
    final ok = await _ch.invokeMethod<bool>(
      'requestPermission',
      {'address': address},
    );
    return ok == true;
  }

  static Future<void> open(String address) async {
    await _ch.invokeMethod<void>('open', {'address': address});
  }

  static Future<void> write(List<int> bytes) async {
    await _ch.invokeMethod<void>('write', {
      'bytes': Uint8List.fromList(bytes),
    });
  }

  static Future<void> close() async {
    await _ch.invokeMethod<void>('close');
  }

  static Future<bool> openCashBox() async {
    final ok = await _ch.invokeMethod<bool>('openCashBox');
    return ok == true;
  }
}
