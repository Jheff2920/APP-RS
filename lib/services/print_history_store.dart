import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/print_job_record.dart';

class PrintHistoryStore {
  PrintHistoryStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _key = 'print_history_v1';
  static const _maxItems = 100;
  static const _uuid = Uuid();

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<PrintJobRecord>> loadAll({String? printerId}) async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((e) => PrintJobRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (printerId == null) return list;
    return list.where((j) => j.printerId == printerId).toList();
  }

  Future<void> _saveAll(List<PrintJobRecord> jobs) async {
    final prefs = await _ensurePrefs();
    final trimmed = jobs.take(_maxItems).toList();
    await prefs.setString(
      _key,
      jsonEncode(trimmed.map((j) => j.toJson()).toList()),
    );
  }

  Future<PrintJobRecord> add({
    required String title,
    required String printerId,
    required String printerName,
    required PrintJobStatus status,
    String source = 'app',
    String? error,
  }) async {
    final record = PrintJobRecord(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      title: title,
      printerId: printerId,
      printerName: printerName,
      status: status,
      source: source,
      error: error,
    );
    final all = await loadAll();
    await _saveAll([record, ...all]);
    return record;
  }

  Future<void> clear({String? printerId}) async {
    if (printerId == null) {
      await _saveAll([]);
      return;
    }
    final kept = (await loadAll()).where((j) => j.printerId != printerId);
    await _saveAll(kept.toList());
  }
}
