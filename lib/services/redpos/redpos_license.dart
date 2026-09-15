import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../printer_store.dart';
import '../../l10n/app_lang.dart';
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

  static RedPosRedeemResult get invalid => RedPosRedeemResult(
        ok: false,
        adsFree: false,
        message: tr('Código no válido', 'Invalid code'),
      );
}

/// Licencia de la instalación (no de una impresora). Imprimir nunca se bloquea.
class RedPosLicenseStore {
  RedPosLicenseStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _key = 'redpos_license_v1';
  static const _usedKey = 'redpos_used_nonces_v1';
  static const playEntitlementKey = 'redpos_play_sub_v1';
  static const googleEmailKey = 'redpos_google_email_v1';
  static const _nativeChannel = MethodChannel('boleta_print/printers_prefs');

  static final RedPosLicenseStore instance = RedPosLicenseStore();

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> isAdsFree({bool reloadDisk = true}) async {
    if (await _loadToken(reloadDisk: reloadDisk) != null) return true;
    final prefs = await _ensurePrefs();
    if (reloadDisk) await prefs.reload();
    return prefs.getBool(playEntitlementKey) == true;
  }

  Future<void> setPlayEntitlement(bool active) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(playEntitlementKey, active);
  }

  /// Correo de Google usado al pagar. Solo vive en SharedPreferences de este
  /// aparato (`redpos_google_email_v1`); no hay cuenta en un servidor RedPOS.
  Future<bool> setGoogleEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    final prefs = await _ensurePrefs();
    final saved = await prefs.setString(googleEmailKey, trimmed);
    if (!saved) return false;
    return prefs.getString(googleEmailKey)?.trim() == trimmed;
  }

  Future<String?> googleEmail({bool reloadDisk = true}) async {
    final prefs = await _ensurePrefs();
    if (reloadDisk) await prefs.reload();
    final value = prefs.getString(googleEmailKey)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> applyToPrinters(PrinterStore store) async {
    final adsFree = await isAdsFree();
    await store.applyAdsFree(adsFree);
    await _syncNative(adsFree);
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

  /// Relee el pase (código o suscripción Play) y lo copia al PrintService.
  Future<bool> hydrate(PrinterStore store) async {
    await applyToPrinters(store);
    return isAdsFree();
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
        message: verified.message ?? tr('Código no válido', 'Invalid code'),
      );
    }

    final api = RedPosConfig.apiBase.trim();
    if (api.isNotEmpty && !verified.testAlias) {
      try {
        final accepted = await _activateOnServer(
          api,
          code: code.trim(),
          address: address ?? '',
        );
        if (!accepted) {
          return RedPosRedeemResult(
            ok: false,
            adsFree: false,
            message: tr(
              'Este código ya fue usado o el servidor lo rechazó',
              'This code was already used or the server rejected it',
            ),
          );
        }
      } catch (e) {
        debugPrint('redpos activate: $e');
        return RedPosRedeemResult(
          ok: false,
          adsFree: false,
          offlinePending: true,
          message: tr(
            'Sin red para validar el código. Puedes imprimir con publicidad y reintentar luego.',
            'No network to validate the code. You can print with ads and try again later.',
          ),
        );
      }
    } else {
      final prefs = await _ensurePrefs();
      final used = prefs.getStringList(_usedKey) ?? [];
      if (!verified.testAlias && used.contains(verified.nonce)) {
        return RedPosRedeemResult(
          ok: false,
          adsFree: false,
          message: tr(
            'Este código ya se usó en este teléfono',
            'This code was already used on this phone',
          ),
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
    return RedPosRedeemResult(
      ok: true,
      adsFree: true,
      message: tr(
        'Activación correcta. Esta instalación no muestra publicidad.',
        'Activated. This install will not show ads.',
      ),
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
