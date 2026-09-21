import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'sunat_logo.dart';

/// Cómo se arma el ticket ESC/POS de un XML/ZIP SUNAT.
enum SunatTicketFormat {
  compacto,
  claro,
  detallado;

  String label(bool english) {
    switch (this) {
      case SunatTicketFormat.compacto:
        return english ? 'Compact' : 'Compacto';
      case SunatTicketFormat.claro:
        return english ? 'Clear' : 'Claro';
      case SunatTicketFormat.detallado:
        return english ? 'Detailed' : 'Detallado';
    }
  }

  String hint(bool english) {
    switch (this) {
      case SunatTicketFormat.compacto:
        return english
            ? 'Shorter ticket, close to the original layout.'
            : 'Ticket más corto, cercano al formato original.';
      case SunatTicketFormat.claro:
        return english
            ? 'Sections, a taller document number, and columns. Recommended.'
            : 'Secciones, número más alto y columnas. Recomendado.';
      case SunatTicketFormat.detallado:
        return english
            ? 'Adds the unit, customer address, time, and more space.'
            : 'Agrega unidad, dirección del cliente, hora y más espacio.';
    }
  }

  static SunatTicketFormat fromName(String? raw) {
    for (final value in SunatTicketFormat.values) {
      if (value.name == raw) return value;
    }
    return SunatTicketFormat.claro;
  }
}

/// Ajustes guardados del ticket SUNAT. El logo vive en otra clave.
class SunatPrintSettings {
  const SunatPrintSettings({
    this.format = SunatTicketFormat.claro,
    this.footerNote = '',
    this.showQr = true,
    this.showLegend = true,
  });

  static const maxNoteLength = 240;

  final SunatTicketFormat format;
  final String footerNote;
  final bool showQr;
  final bool showLegend;

  /// `noteOverride == null` conserva la nota guardada. Cadena vacía la quita
  /// solo en ese trabajo.
  SunatPrintSettings forJob(String? noteOverride) {
    if (noteOverride == null) return this;
    return copyWith(footerNote: normalizeNote(noteOverride));
  }

  SunatPrintSettings copyWith({
    SunatTicketFormat? format,
    String? footerNote,
    bool? showQr,
    bool? showLegend,
  }) {
    return SunatPrintSettings(
      format: format ?? this.format,
      footerNote: footerNote ?? this.footerNote,
      showQr: showQr ?? this.showQr,
      showLegend: showLegend ?? this.showLegend,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format.name,
        'footerNote': footerNote,
        'showQr': showQr,
        'showLegend': showLegend,
      };

  factory SunatPrintSettings.fromJson(Map<String, dynamic> json) {
    return SunatPrintSettings(
      format: SunatTicketFormat.fromName(json['format'] as String?),
      footerNote: normalizeNote(json['footerNote'] as String? ?? ''),
      showQr: json['showQr'] as bool? ?? true,
      showLegend: json['showLegend'] as bool? ?? true,
    );
  }

  static String normalizeNote(String raw) {
    final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (text.length <= maxNoteLength) return text;
    return text.substring(0, maxNoteLength);
  }
}

/// Preferencias del ticket SUNAT. El logo ya reducido va en base64.
class SunatPrintStore {
  SunatPrintStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const settingsKey = 'sunat_print_settings_v1';
  static const logoKey = 'sunat_print_logo_b64_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  Future<SunatPrintSettings> load() async {
    final prefs = await _ensure();
    final raw = prefs.getString(settingsKey);
    if (raw == null || raw.isEmpty) return const SunatPrintSettings();
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const SunatPrintSettings();
      return SunatPrintSettings.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return const SunatPrintSettings();
    }
  }

  Future<void> save(SunatPrintSettings settings) async {
    final prefs = await _ensure();
    final normalized = settings.copyWith(
      footerNote: SunatPrintSettings.normalizeNote(settings.footerNote),
    );
    await prefs.setString(settingsKey, jsonEncode(normalized.toJson()));
  }

  Future<Uint8List?> loadLogoBytes() async {
    final prefs = await _ensure();
    final raw = prefs.getString(logoKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final bytes = base64Decode(raw);
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasLogo() async {
    final bytes = await loadLogoBytes();
    return bytes != null && bytes.isNotEmpty;
  }

  /// Guarda un PNG/JPG ya aplastado y reducido. No toca el resto de ajustes.
  Future<void> saveLogo(Uint8List raw) async {
    final prepared = SunatLogo.preparePng(raw);
    final prefs = await _ensure();
    await prefs.setString(logoKey, base64Encode(prepared));
  }

  Future<void> clearLogo() async {
    final prefs = await _ensure();
    await prefs.remove(logoKey);
  }
}
