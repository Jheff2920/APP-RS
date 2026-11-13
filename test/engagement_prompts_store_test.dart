import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hello_world_app/services/engagement_prompts_store.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('rating: no pide antes del mínimo de impresiones', () async {
    final store = EngagementPromptsStore(prefs: prefs);
    await store.recordSuccessfulPrint();
    await store.recordSuccessfulPrint();
    expect(await store.shouldShowRatingPrompt(), isFalse);
    await store.recordSuccessfulPrint();
    expect(await store.shouldShowRatingPrompt(), isTrue);
  });

  test('rating: "después" espera 30 días; "listo" no vuelve a pedir nunca',
      () async {
    final store = EngagementPromptsStore(prefs: prefs);
    for (var i = 0; i < EngagementPromptsStore.minPrintsBeforeAsking; i++) {
      await store.recordSuccessfulPrint();
    }
    final now = DateTime(2026, 1, 1);
    await store.markRatingLater(now: now);
    expect(await store.shouldShowRatingPrompt(now: now.add(const Duration(days: 10))),
        isFalse);
    expect(
        await store.shouldShowRatingPrompt(now: now.add(const Duration(days: 31))),
        isTrue);
    await store.markRatingDone();
    expect(
        await store.shouldShowRatingPrompt(now: now.add(const Duration(days: 365))),
        isFalse);
  });

  test(
      'recordatorio de activación: la primera revisión no muestra nada, '
      'luego como mucho 1 vez al día', () async {
    final store = EngagementPromptsStore(prefs: prefs);
    final now = DateTime(2026, 1, 1, 9);
    expect(await store.shouldShowActivationReminder(now: now), isFalse);
    expect(
        await store.shouldShowActivationReminder(now: now.add(const Duration(hours: 2))),
        isFalse);
    expect(
        await store.shouldShowActivationReminder(now: now.add(const Duration(days: 1, minutes: 1))),
        isTrue);
    await store.markActivationReminderShown(now: now.add(const Duration(days: 1)));
    expect(
        await store.shouldShowActivationReminder(now: now.add(const Duration(days: 1, hours: 5))),
        isFalse);
  });
}
