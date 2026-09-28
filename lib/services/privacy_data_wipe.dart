import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_ticket/custom_ticket_store.dart';
import 'print_history_store.dart';
import 'printer_store.dart';
import 'redpos/redpos_config.dart';
import 'redpos/redpos_license.dart';
import 'sunat/sunat_print_settings.dart';

/// Resultado del borrado local de datos de privacidad.
class PrivacyWipeResult {
  const PrivacyWipeResult({
    required this.ok,
    this.clearedKeys = const [],
    this.message,
  });

  final bool ok;
  final List<String> clearedKeys;
  final String? message;
}

/// Borra datos locales de la app (prefs, plantillas, logos, licencia local).
/// No cancela la suscripción de Play ni borra el canje en el servidor RedPOS.
class PrivacyDataWipe {
  PrivacyDataWipe({
    PrinterStore? printerStore,
    PrintHistoryStore? historyStore,
    CustomTicketStore? ticketStore,
    SunatPrintStore? sunatStore,
    RedPosLicenseStore? licenseStore,
    SharedPreferences? prefs,
  })  : _printerStore = printerStore ?? PrinterStore(),
        _historyStore = historyStore ?? PrintHistoryStore(),
        _ticketStore = ticketStore ?? CustomTicketStore(),
        _sunatStore = sunatStore ?? SunatPrintStore(),
        _licenseStore = licenseStore ?? RedPosLicenseStore.instance,
        _prefs = prefs;

  final PrinterStore _printerStore;
  final PrintHistoryStore _historyStore;
  final CustomTicketStore _ticketStore;
  final SunatPrintStore _sunatStore;
  final RedPosLicenseStore _licenseStore;
  SharedPreferences? _prefs;

  static const knownKeys = <String>[
    'saved_printers_v1',
    'print_history_v1',
    CustomTicketStore.templatesKey,
    SunatPrintStore.settingsKey,
    SunatPrintStore.logoKey,
    'redpos_license_v1',
    'redpos_used_nonces_v1',
    RedPosLicenseStore.playEntitlementKey,
    RedPosLicenseStore.googleEmailKey,
  ];

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<PrivacyWipeResult> wipeLocal() async {
    final cleared = <String>[];
    try {
      await _printerStore.clearAll();
      cleared.add('saved_printers_v1');

      await _historyStore.clear();
      cleared.add('print_history_v1');

      await _ticketStore.clearAll();
      cleared.add(CustomTicketStore.templatesKey);

      await _sunatStore.clearAll();
      cleared.add(SunatPrintStore.settingsKey);
      cleared.add(SunatPrintStore.logoKey);

      await _licenseStore.clearLocalLicense();
      cleared.addAll([
        'redpos_license_v1',
        'redpos_used_nonces_v1',
        RedPosLicenseStore.playEntitlementKey,
        RedPosLicenseStore.googleEmailKey,
      ]);

      // Por si quedaron claves huérfanas de versiones anteriores.
      final prefs = await _ensurePrefs();
      await prefs.reload();
      for (final key in knownKeys) {
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
          if (!cleared.contains(key)) cleared.add(key);
        }
      }

      await _signOutGoogleQuietly();
      await _bestEffortClearTempCache();

      return PrivacyWipeResult(ok: true, clearedKeys: cleared);
    } catch (e, st) {
      debugPrint('PrivacyDataWipe: $e\n$st');
      return PrivacyWipeResult(
        ok: false,
        clearedKeys: cleared,
        message: e.toString(),
      );
    }
  }

  Future<void> _signOutGoogleQuietly() async {
    if (kIsWeb) return;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return;
      final webId = RedPosConfig.googleServerClientId.trim();
      await GoogleSignIn.instance.initialize(
        serverClientId: webId.isEmpty ? null : webId,
      );
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('PrivacyDataWipe google signOut: $e');
    }
  }

  /// Borra copias temporales legibles (share/open) si viven bajo systemTemp.
  Future<void> _bestEffortClearTempCache() async {
    if (kIsWeb) return;
    try {
      final tmp = Directory.systemTemp;
      if (!await tmp.exists()) return;
      await for (final entity in tmp.list(followLinks: false)) {
        final name = entity.uri.pathSegments.isEmpty
            ? ''
            : entity.uri.pathSegments.last.toLowerCase();
        final looksOurs = name.contains('boleta') ||
            name.contains('redpos') ||
            name.contains('sunat') ||
            name.endsWith('.pdf') ||
            name.endsWith('.xml') ||
            name.endsWith('.zip');
        if (!looksOurs) continue;
        try {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('PrivacyDataWipe temp: $e');
    }
  }
}
