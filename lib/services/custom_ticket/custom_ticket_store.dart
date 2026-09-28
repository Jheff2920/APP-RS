import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'custom_ticket.dart';

/// Persistencia de plantillas de tickets propios (JSON en SharedPreferences).
class CustomTicketStore {
  CustomTicketStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const templatesKey = 'custom_tickets_v1';
  static const _uuid = Uuid();

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  Future<List<CustomTicketTemplate>> loadAll() async {
    final prefs = await _ensure();
    final raw = prefs.getString(templatesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final list = <CustomTicketTemplate>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        final t = CustomTicketTemplate.fromJson(Map<String, dynamic>.from(e));
        if (t.id.isEmpty) continue;
        list.add(t);
      }
      list.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<CustomTicketTemplate?> loadById(String id) async {
    if (id.isEmpty) return null;
    final all = await loadAll();
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> save(CustomTicketTemplate template) async {
    final all = await loadAll();
    final clipped = CustomTicketTemplate.fromJson(template.toJson()).copyWith(
      name: _clipName(template.name),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      logoBytes: template.logoBytes,
    );
    final idx = all.indexWhere((t) => t.id == clipped.id);
    if (idx >= 0) {
      all[idx] = clipped;
    } else {
      all.insert(0, clipped);
    }
    await _writeAll(all);
  }

  Future<CustomTicketTemplate> create({String? name}) async {
    final template = CustomTicketTemplate(
      id: _uuid.v4(),
      name: _clipName(name ?? 'Nuevo ticket'),
      title: '',
      lines: const [
        CustomTicketLine(
          type: CustomTicketLineType.item,
          text: '',
          qty: '1',
        ),
      ],
      showTotals: true,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await save(template);
    return template;
  }

  Future<void> clearAll() async {
    await _writeAll([]);
  }

  Future<void> delete(String id) async {
    if (id.isEmpty) return;
    final all = await loadAll();
    all.removeWhere((t) => t.id == id);
    await _writeAll(all);
  }

  Future<CustomTicketTemplate> duplicate(CustomTicketTemplate source) async {
    final copy = source.copyWith(
      id: _uuid.v4(),
      name: _clipName('${source.name} (copia)'),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await save(copy);
    return copy;
  }

  Future<void> _writeAll(List<CustomTicketTemplate> templates) async {
    final prefs = await _ensure();
    final encoded = jsonEncode(templates.map((t) => t.toJson()).toList());
    await prefs.setString(templatesKey, encoded);
  }

  static String _clipName(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Ticket';
    if (t.length <= CustomTicketTemplate.maxNameLength) return t;
    return t.substring(0, CustomTicketTemplate.maxNameLength);
  }
}