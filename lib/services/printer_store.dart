import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/saved_printer.dart';

class PrinterStore {
  PrinterStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _key = 'saved_printers_v1';
  static const _uuid = Uuid();
  static const _nativeChannel = MethodChannel('boleta_print/printers_prefs');

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<SavedPrinter>> loadAll() async {
    final prefs = await _ensurePrefs();
    // Reload desde disco: el engine headless (PrintService) no ve cambios
    // guardados por la UI si usa la caché en memoria de SharedPreferences.
    await prefs.reload();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final parsed = list
        .map((e) => SavedPrinter.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final cleaned = _ensureSingleDefault(_dedupeByAddress(parsed));
    if (!_sameList(parsed, cleaned)) {
      await _saveAll(cleaned);
    }
    return cleaned;
  }

  /// Resuelve por id; si no, predeterminada o la primera.
  static SavedPrinter? findByIdOrDefault(
    List<SavedPrinter> printers,
    String printerId,
  ) {
    if (printerId.isNotEmpty) {
      for (final p in printers) {
        if (p.id == printerId) return p;
      }
    }
    for (final p in printers) {
      if (p.isDefault) return p;
    }
    return printers.isEmpty ? null : printers.first;
  }

  static bool _sameList(List<SavedPrinter> a, List<SavedPrinter> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].isDefault != b[i].isDefault ||
          a[i].paper != b[i].paper ||
          a[i].address != b[i].address) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveAll(List<SavedPrinter> printers) async {
    final prefs = await _ensurePrefs();
    final encoded = jsonEncode(printers.map((p) => p.toJson()).toList());
    await prefs.setString(_key, encoded);
    await _pushNative(encoded);
  }

  /// Copia a SharedPreferences nativas (descubrimiento del PrintService).
  Future<void> syncNativePrefs() async {
    final all = await loadAll();
    await _pushNative(jsonEncode(all.map((p) => p.toJson()).toList()));
  }

  Future<void> _pushNative(String encoded) async {
    try {
      await _nativeChannel.invokeMethod('syncPrintersJson', encoded);
    } catch (e) {
      debugPrint('syncPrintersJson: $e');
    }
  }

  String newId() => _uuid.v4();

  Future<List<SavedPrinter>> upsert(SavedPrinter printer) async {
    final all = await loadAll();
    var next = List<SavedPrinter>.from(all);

    // Misma impresora física (MAC/IP): actualizar, no duplicar.
    var index = next.indexWhere((p) => p.id == printer.id);
    if (index < 0) {
      index = next.indexWhere((p) => _sameDevice(p, printer));
    }

    final keepId = index >= 0 ? next[index].id : printer.id;
    var toSave = printer.copyWith(id: keepId);

    if (toSave.isDefault) {
      next = next.map((p) => p.copyWith(isDefault: false)).toList();
    }

    if (next.isEmpty) {
      toSave = toSave.copyWith(isDefault: true);
    }

    if (index >= 0) {
      next[index] = toSave;
    } else {
      next.add(toSave);
    }

    next = _ensureSingleDefault(next);
    await _saveAll(next);
    return next;
  }

  Future<List<SavedPrinter>> delete(String id) async {
    var next = (await loadAll()).where((p) => p.id != id).toList();
    next = _ensureSingleDefault(next);
    await _saveAll(next);
    return next;
  }

  Future<List<SavedPrinter>> setDefault(String id) async {
    final next = _ensureSingleDefault(
      (await loadAll()).map((p) => p.copyWith(isDefault: p.id == id)).toList(),
    );
    await _saveAll(next);
    return next;
  }

  static bool _sameDevice(SavedPrinter a, SavedPrinter b) {
    if (a.type != b.type) return false;
    final aa = a.address.trim().toLowerCase();
    final bb = b.address.trim().toLowerCase();
    if (aa.isEmpty || bb.isEmpty || aa != bb) return false;
    if (a.type == PrinterLinkType.network && a.port != b.port) return false;
    return true;
  }

  /// Si Probar + Guardar crearon dos filas con la misma MAC, deja una.
  static List<SavedPrinter> _dedupeByAddress(List<SavedPrinter> list) {
    final out = <SavedPrinter>[];
    for (final p in list) {
      final i = out.indexWhere((e) => _sameDevice(e, p));
      if (i < 0) {
        out.add(p);
        continue;
      }
      // Conserva la que sea default / la más reciente en la lista.
      final prev = out[i];
      out[i] = p.copyWith(
        id: prev.id,
        isDefault: prev.isDefault || p.isDefault,
        // Preferir papel/márgenes del último guardado.
        paper: p.paper,
        margins: p.margins,
        name: p.name.isNotEmpty ? p.name : prev.name,
      );
    }
    return out;
  }

  static List<SavedPrinter> _ensureSingleDefault(List<SavedPrinter> list) {
    if (list.isEmpty) return list;
    if (list.where((p) => p.isDefault).length == 1) return list;
    final preferred = list.firstWhere(
      (p) => p.isDefault,
      orElse: () => list.first,
    );
    return list
        .map((p) => p.copyWith(isDefault: p.id == preferred.id))
        .toList();
  }
}
