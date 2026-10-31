import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/saved_printer.dart';
import '../models/physical_printer.dart';

class PrinterStore {
  PrinterStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _key = 'printer_catalog_v2';
  static const legacyKey = 'saved_printers_v1';
  static const _uuid = Uuid();
  static const _nativeChannel = MethodChannel('boleta_print/printers_prefs');

  static Future<void>? _tail;
  static Future<T> _exclusive<T>(Future<T> Function() action) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    if (previous != null) await previous;
    try {
      return await action();
    } finally {
      done.complete();
      if (identical(_tail, done.future)) _tail = null;
    }
  }

  Future<List<SavedPrinter>> loadAll() => _exclusive(_loadAll);
  Future<List<SavedPrinter>> upsert(SavedPrinter printer) =>
      _exclusive(() => _upsert(printer));
  Future<List<SavedPrinter>> delete(String id) => _exclusive(() => _delete(id));
  Future<void> clearAll() => _exclusive(_clearAll);
  Future<void> syncNativePrefs() => _exclusive(_syncNativePrefs);
  Future<List<SavedPrinter>> setDefault(String id) =>
      _exclusive(() => _setDefault(id));
  Future<List<SavedPrinter>> applyAdsFree(bool value) =>
      _exclusive(() => _applyAdsFree(value));
  Future<List<String>> deleteByAddress(String address,
          {PrinterLinkType? type}) =>
      _exclusive(() => _deleteByAddress(address, type: type));

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<SavedPrinter>> _loadAll() async {
    final prefs = await _ensurePrefs();
    // Reload desde disco: el engine headless (PrintService) no ve cambios
    // guardados por la UI si usa la caché en memoria de SharedPreferences.
    await prefs.reload();
    final catalog = prefs.getString(_key);
    if (catalog != null && catalog.isNotEmpty) {
      final data = Map<String, dynamic>.from(jsonDecode(catalog) as Map);
      if (data['schemaVersion'] != 2) {
        throw const FormatException('Unsupported printer schema');
      }
      final physical = {
        for (final row in data['physicalPrinters'] as List)
          (row as Map)['physicalPrinterId'] as String:
              Map<String, dynamic>.from(row)
      };
      return (data['logicalPrinters'] as List).map((row) {
        final logical = Map<String, dynamic>.from(row as Map);
        final hardware = physical[logical['physicalPrinterId']];
        if (hardware == null) {
          throw const FormatException('Missing physical printer');
        }
        return SavedPrinter.fromJson({
          ...logical,
          'type': hardware['type'],
          'address': hardware['address'],
          'port': hardware['port']
        });
      }).toList();
    }
    final raw = prefs.getString(legacyKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    // Preserve v1 as a recovery backup. Only legacy accidental duplicates merge.
    final parsed = list
        .map((e) => SavedPrinter.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final migrated = _ensureSingleDefault(_dedupeByAddress(parsed));
    await _saveAll(migrated);
    return migrated;
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
      return null; // Explicit missing IDs must never print elsewhere.
    }
    for (final p in printers) {
      if (p.isDefault) return p;
    }
    return printers.isEmpty ? null : printers.first;
  }

  Future<void> _saveAll(List<SavedPrinter> printers) async {
    final prefs = await _ensurePrefs();
    final previousRaw = prefs.getString(_key);
    final previous = previousRaw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(previousRaw) as Map);
    final oldPhysical = {
      for (final row in previous['physicalPrinters'] as List? ?? [])
        (row as Map)['physicalPrinterId']: Map<String, dynamic>.from(row)
    };
    final physical = <String, Map<String, dynamic>>{};
    for (final p in printers) {
      physical.putIfAbsent(
          p.physicalPrinterId,
          () => PhysicalPrinter(
                physicalPrinterId: p.physicalPrinterId,
                deviceName: oldPhysical[p.physicalPrinterId]?['deviceName']
                        as String? ??
                    p.name,
                transport: p.type,
                address: p.address,
                port: p.port,
                verifiedCapabilities: Map<String, dynamic>.from(
                    oldPhysical[p.physicalPrinterId]?['verifiedCapabilities']
                            as Map? ??
                        {}),
              ).toJson());
    }
    final logical = printers
        .map((p) => p.toJson()
          ..remove('type')
          ..remove('address')
          ..remove('port'))
        .toList();
    final encoded = jsonEncode({
      'schemaVersion': 2,
      'physicalPrinters': physical.values.toList(),
      'logicalPrinters': logical
    });
    if (!await prefs.setString(_key, encoded)) {
      throw StateError('Printer save failed');
    }
    await _pushNative(jsonEncode(printers.map((p) => p.toJson()).toList()));
  }

  /// Copia a SharedPreferences nativas (descubrimiento del PrintService).
  Future<void> _syncNativePrefs() async {
    final all = await _loadAll();
    await _pushNative(jsonEncode(all.map((p) => p.toJson()).toList()));
  }

  Future<void> _pushNative(String encoded) async {
    try {
      await _nativeChannel.invokeMethod('syncPrintersJson', encoded);
    } on MissingPluginException catch (e) {
      debugPrint('syncPrintersJson: $e');
    }
  }

  String newId() => _uuid.v4();

  Future<List<SavedPrinter>> _upsert(SavedPrinter printer) async {
    final all = await _loadAll();
    var next = List<SavedPrinter>.from(all);

    if (printer.enabledProfiles.isEmpty) {
      throw ArgumentError('Enable a paper size');
    }
    for (final profile in printer.paperProfiles) {
      if (profile.logicalPrinterId != printer.id ||
          profile.isLabel != printer.isLabel) {
        throw ArgumentError('Paper profile belongs to another destination');
      }
      if (printer.isLabel && profile.validationError != null) {
        throw ArgumentError(profile.validationError);
      }
    }
    if (printer.paperProfiles.map((p) => p.paperProfileId).toSet().length !=
        printer.paperProfiles.length) {
      throw ArgumentError('Duplicate paper profile identity');
    }
    if (!printer.isLabel && printer.protocol != PrinterProtocol.escpos) {
      throw ArgumentError('Receipts require ESC/POS');
    }
    final index = next.indexWhere((p) => p.id == printer.id);
    final hardware = next
            .where((p) => p.id != printer.id && _sameDevice(p, printer))
            .firstOrNull ??
        next
            .where((p) =>
                p.id != printer.id &&
                p.physicalPrinterId == printer.physicalPrinterId)
            .firstOrNull;
    var toSave = printer.copyWith(
        physicalPrinterId:
            hardware?.physicalPrinterId ?? printer.physicalPrinterId);
    // A connection edit affects the shared hardware; print settings stay local.
    next = next
        .map((p) => p.physicalPrinterId == toSave.physicalPrinterId ||
                p.physicalPrinterId == printer.physicalPrinterId
            ? p.copyWith(
                physicalPrinterId: toSave.physicalPrinterId,
                type: toSave.type,
                address: toSave.address,
                port: toSave.port)
            : p)
        .toList();

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

  /// Borra todas las impresoras vinculadas (prefs + nativo PrintService).
  Future<void> _clearAll() async {
    await _saveAll([]);
    final prefs = await _ensurePrefs();
    await prefs.remove(legacyKey);
  }

  Future<List<SavedPrinter>> _delete(String id) async {
    var next = (await _loadAll()).where((p) => p.id != id).toList();
    next = _ensureSingleDefault(next);
    await _saveAll(next);
    return next;
  }

  /// Quita las impresoras guardadas de esa dirección (p. ej. al olvidar BT).
  Future<List<String>> _deleteByAddress(
    String address, {
    PrinterLinkType? type,
  }) async {
    final key = address.trim().toLowerCase();
    if (key.isEmpty) return const [];
    final all = await _loadAll();
    final removed = <String>[];
    final kept = <SavedPrinter>[];
    for (final p in all) {
      final sameType = type == null || p.type == type;
      if (sameType && p.address.trim().toLowerCase() == key) {
        removed.add(p.id);
      } else {
        kept.add(p);
      }
    }
    if (removed.isEmpty) return const [];
    await _saveAll(_ensureSingleDefault(kept));
    return removed;
  }

  Future<List<SavedPrinter>> _setDefault(String id) async {
    final next = _ensureSingleDefault(
      (await _loadAll()).map((p) => p.copyWith(isDefault: p.id == id)).toList(),
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
        physicalPrinterId: prev.physicalPrinterId,
        paperProfiles: PaperProfile.receipts(prev.id),
        defaultPaperProfileId: '',
        isDefault: prev.isDefault || p.isDefault,
        paper: p.paper,
        dpi: p.dpi,
        rasterScale: p.rasterScale,
        cut: p.cut,
        cashDrawer: p.cashDrawer,
        margins: p.margins,
        name: p.name.isNotEmpty ? p.name : prev.name,
        adsFree: p.adsFree || prev.adsFree,
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

  /// Copia el pase de la instalación a cada impresora (PrintService nativo).
  Future<List<SavedPrinter>> _applyAdsFree(bool adsFree) async {
    final all = await _loadAll();
    if (all.every((p) => p.adsFree == adsFree)) return all;
    final next = all.map((p) => p.copyWith(adsFree: adsFree)).toList();
    await _saveAll(next);
    return next;
  }
}
