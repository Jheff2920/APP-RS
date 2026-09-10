import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../printer_store.dart';
import 'redpos_code.dart';
import 'redpos_config.dart';

class RedPosRedeemResult {
  const RedPosRedeemResult({
    required this.ok,
    required this.adsFree,
    this.message,
    this.offlinePending = false,
  });

  final bool ok;
  final bool adsFree;
  final String? message;
  final bool offlinePending;

  static const invalid = RedPosRedeemResult(
    ok: false,
    adsFree: false,
    message: 'Código no válido',
  );
}

/// Licencia de la instalación (no de una impresora). Imprimir nunca se bloquea.
class RedPosLicenseStore {
  RedPosLicenseStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _key = 'redpos_license_v1';
  static const _usedKey = 'redpos_used_nonces_v1';
  static const _nativeChannel = MethodChannel('boleta_print/printers_prefs');

  static final RedPosLicenseStore instance = RedPosLicenseStore();

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> isAdsFree({bool reloadDisk = true}) async {
    final token = await _loadToken(reloadDisk: reloadDisk);
    return token != null;
  }

  Future<RedPosLicenseToken?> _loadToken({bool reloadDisk = true}) async {
    final prefs = await _ensurePrefs();
    if (reloadDisk) await prefs.reload();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    final token = RedPosLicenseToken.tryDecode(raw);
    if (token == null || token.nonce.isEmpty) return null;
    if (token.nonce == 'TESTALIAS') {
      return RedPosConfig.allowTestCodes ? token : null;
    }
    // El nonce fue firmado al canjear; no confiamos en un bool suelto.
    if (token.nonce.length != 8) return null;
    return token;
  }

  Future<void> _saveToken(RedPosLicenseToken token) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_key, token.encode());
    await _syncNative(true);
  }

  Future<void> _syncNative(bool adsFree) async {
    try {
      await _nativeChannel.invokeMethod('syncAdsFree', adsFree);
    } catch (e) {
      debugPrint('syncAdsFree: $e');
    }
  }

  /// Relee el pase y lo copia a las impresoras (PrintService nativo).
  Future<bool> hydrate(PrinterStore store) async {
    final adsFree = await isAdsFree();
    await store.applyAdsFree(adsFree);
    await _syncNative(adsFree);
    return adsFree;
  }

  Future<RedPosRedeemResult> redeem(
    String code, {
    required PrinterStore store,
    String? address,
  }) async {
    final verified = RedPosCode.verify(code);
    if (!verified.ok || verified.nonce == null) {
      return RedPosRedeemResult(
        ok: false,
        adsFree: false,
        message: verified.message ?? 'Código no válido',
      );
    }

    final api = RedPosConfig.apiBase.trim();
    if (api.isNotEmpty) {
      try {
        final accepted = await _activateOnServer(
          api,
          code: code.trim(),
          address: address ?? '',
        );
        if (!accepted) {
          return const RedPosRedeemResult(
            ok: false,
            adsFree: false,
            message: 'Este código ya fue usado o el servidor lo rechazó',
          );
        }
      } catch (e) {
        debugPrint('redpos activate: $e');
        return const RedPosRedeemResult(
          ok: false,
          adsFree: false,
          offlinePending: true,
          message:
              'Sin red para validar el código. Puedes imprimir con publicidad y reintentar luego.',
        );
      }
    } else {
      final prefs = await _ensurePrefs();
      final used = prefs.getStringList(_usedKey) ?? [];
      if (!verified.testAlias && used.contains(verified.nonce)) {
        return const RedPosRedeemResult(
          ok: false,
          adsFree: false,
          message: 'Este código ya se usó en este teléfono',
        );
      }
      if (!verified.testAlias) {
        await prefs.setStringList(_usedKey, [...used, verified.nonce!]);
      }
    }

    await _saveToken(
      RedPosLicenseToken(
        nonce: verified.nonce!,
        issuedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await store.applyAdsFree(true);
    return const RedPosRedeemResult(
      ok: true,
      adsFree: true,
      message: 'Activación correcta. Esta instalación no muestra publicidad.',
    );
  }

  Future<bool> _activateOnServer(
    String apiBase, {
    required String code,
    required String address,
  }) async {
    final uri = Uri.parse(apiBase).resolve('/api/activate');
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri).timeout(const Duration(seconds: 8));
      req.headers.contentType = ContentType.json;
      req.add(
        utf8.encode(
          jsonEncode({
            'code': code,
            'address': address,
          }),
        ),
      );
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await utf8.decodeStream(res);
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['ok'] == true) return true;
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
