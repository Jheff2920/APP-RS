import 'package:shared_preferences/shared_preferences.dart';

/// Cuándo mostrar el aviso de activación (al abrir, 1 vez al día) y el de
/// valoración (tras varias impresiones exitosas, sin volver a molestar).
/// Ninguno de los dos bloquea imprimir; solo decide si un diálogo aparece.
class EngagementPromptsStore {
  EngagementPromptsStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _printCountKey = 'engagement_print_count_v1';
  static const _ratingStatusKey = 'engagement_rating_status_v1';
  static const _ratingLaterUntilKey = 'engagement_rating_later_until_v1';
  static const _adReminderLastKey = 'engagement_ad_reminder_last_v1';

  /// Impresiones exitosas antes de preguntar la primera vez.
  static const minPrintsBeforeAsking = 3;

  /// Si eligió "Después", no se vuelve a preguntar antes de este tiempo.
  static const laterDelay = Duration(days: 30);

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Se llama una vez por cada trabajo que terminó con éxito.
  Future<void> recordSuccessfulPrint() async {
    final prefs = await _ensurePrefs();
    await prefs.setInt(_printCountKey, (prefs.getInt(_printCountKey) ?? 0) + 1);
  }

  Future<bool> shouldShowRatingPrompt({DateTime? now}) async {
    final prefs = await _ensurePrefs();
    if (prefs.getString(_ratingStatusKey) == 'done') return false;
    final count = prefs.getInt(_printCountKey) ?? 0;
    if (count < minPrintsBeforeAsking) return false;
    final laterRaw = prefs.getString(_ratingLaterUntilKey);
    if (laterRaw == null) return true;
    final later = DateTime.tryParse(laterRaw);
    if (later == null) return true;
    return (now ?? DateTime.now()).isAfter(later);
  }

  /// Ya calificó o escribió feedback: no se le vuelve a pedir.
  Future<void> markRatingDone() async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_ratingStatusKey, 'done');
  }

  /// Eligió "Después": se espera [laterDelay] antes de volver a preguntar.
  Future<void> markRatingLater({DateTime? now}) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(
      _ratingLaterUntilKey,
      (now ?? DateTime.now()).add(laterDelay).toIso8601String(),
    );
  }

  /// La primera vez que se revisa (instalación nueva) solo guarda la fecha
  /// y no muestra nada: no tiene sentido pedir activar segundos después de
  /// instalar. A partir de la siguiente apertura, como mucho 1 vez al día.
  Future<bool> shouldShowActivationReminder({DateTime? now}) async {
    final prefs = await _ensurePrefs();
    final lastRaw = prefs.getString(_adReminderLastKey);
    if (lastRaw == null) {
      await markActivationReminderShown(now: now);
      return false;
    }
    final last = DateTime.tryParse(lastRaw);
    if (last == null) return true;
    final current = now ?? DateTime.now();
    return current.difference(last) >= const Duration(days: 1);
  }

  Future<void> markActivationReminderShown({DateTime? now}) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(
      _adReminderLastKey,
      (now ?? DateTime.now()).toIso8601String(),
    );
  }
}
