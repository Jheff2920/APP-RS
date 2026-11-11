import 'package:flutter_test/flutter_test.dart';
import 'package:hello_world_app/services/redpos/redpos_code.dart';
import 'package:hello_world_app/services/redpos/redpos_config.dart';
import 'package:hello_world_app/services/redpos/redpos_license.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('play entitlement without a code is ads-free', () async {
    SharedPreferences.setMockInitialValues({
      RedPosLicenseStore.playEntitlementKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = RedPosLicenseStore(prefs: prefs);
    expect(await store.isAdsFree(reloadDisk: false), isTrue);
  });

  test('play entitlement expires if Play does not confirm it again', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    Future<bool> adsFreeWith(int? verifiedAt) async {
      SharedPreferences.setMockInitialValues({
        RedPosLicenseStore.playEntitlementKey: true,
        if (verifiedAt != null) RedPosLicenseStore.playVerifiedKey: verifiedAt,
      });
      final prefs = await SharedPreferences.getInstance();
      return RedPosLicenseStore(prefs: prefs).isAdsFree(reloadDisk: false);
    }

    final day = const Duration(days: 1).inMilliseconds;
    expect(await adsFreeWith(now - 2 * day), isTrue);
    expect(await adsFreeWith(now - 36 * day), isFalse);
    // Guardado por una versión anterior (sin fecha): el plazo empieza ahora.
    expect(await adsFreeWith(null), isTrue);
    final legacy = await SharedPreferences.getInstance();
    expect(legacy.getInt(RedPosLicenseStore.playVerifiedKey), isNotNull);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = RedPosLicenseStore(prefs: prefs);
    await store.setPlayEntitlement(true);
    expect(prefs.getInt(RedPosLicenseStore.playVerifiedKey), isNotNull);
    await store.setPlayEntitlement(false);
    expect(prefs.getInt(RedPosLicenseStore.playVerifiedKey), isNull);
    expect(await store.isAdsFree(reloadDisk: false), isFalse);
  });

  test('google email persists in local prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = RedPosLicenseStore(prefs: prefs);
    expect(await store.setGoogleEmail('  buyer@gmail.com  '), isTrue);
    expect(await store.googleEmail(reloadDisk: false), 'buyer@gmail.com');
  });

  test('no token and no play entitlement keeps ads', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = RedPosLicenseStore(prefs: prefs);
    expect(await store.isAdsFree(reloadDisk: false), isFalse);
  });

  test('lifetime mailto asks for a permanent license', () {
    final uri = RedPosConfig.lifetimeMailtoUri;
    expect(uri.scheme, 'mailto');
    expect(uri.toString(), contains(RedPosConfig.supportEmail));
    // El subject varía según el idioma del dispositivo.
    final s = uri.toString();
    expect(s.contains('Licencia') || s.contains('Lifetime'), isTrue);
  });

  test('codes are always redeemed on the server by default', () {
    expect(RedPosConfig.apiBase, 'https://redpos-codigos-prueba.vercel.app');
  });

  group('code field formatting', () {
    String typeChars(String chars) {
      var text = '';
      for (final ch in chars.split('')) {
        text = RedPosCode.formatInput(text + ch);
      }
      return text;
    }

    test('typing lowercase without dashes completes RP-XXXX-XXXX-XXXX', () {
      expect(typeChars('pkrd5k5dy5h4'), 'RP-PKRD-5K5D-Y5H4');
      expect(typeChars('pkrd5k5dy5h4xyz'), 'RP-PKRD-5K5D-Y5H4');
    });

    test('typing the prefix by hand does not duplicate it', () {
      expect(typeChars('rp-pkrd-5k5d-y5h4'), 'RP-PKRD-5K5D-Y5H4');
      expect(typeChars('rppkrd5k5dy5h4'), 'RP-PKRD-5K5D-Y5H4');
      expect(typeChars('rp-rpab-cdef-ghjk'), 'RP-RPAB-CDEF-GHJK');
    });

    test('body starting with R typed without prefix', () {
      expect(typeChars('r7xk5k5dy5h4'), 'RP-R7XK-5K5D-Y5H4');
    });

    test('paste: full code, bare body, spaces, inside a message', () {
      expect(RedPosCode.formatInput('rp-pkrd-5k5d-y5h4'), 'RP-PKRD-5K5D-Y5H4');
      expect(RedPosCode.formatInput(' PKRD5K5DY5H4 '), 'RP-PKRD-5K5D-Y5H4');
      expect(RedPosCode.formatInput('RPAB CDEF GHJK'), 'RP-RPAB-CDEF-GHJK');
      expect(RedPosCode.formatInput('rp pkrd 5k5d y5h4'), 'RP-PKRD-5K5D-Y5H4');
      expect(
        RedPosCode.formatInput('Hola, tu key es: RP-PKRD-5K5D-Y5H4. Gracias'),
        'RP-PKRD-5K5D-Y5H4',
      );
    });

    test('deleting back to the empty prefix clears the field', () {
      expect(RedPosCode.formatInput('RP-PKRD-'), 'RP-PKRD');
      expect(RedPosCode.formatInput('RP-', deleting: true), '');
      expect(RedPosCode.formatInput('RP', deleting: true), '');
      expect(RedPosCode.formatInput(''), '');
    });

    test('formatted code still verifies', () {
      final code = RedPosCode.generate();
      final typed = typeChars(code.substring(3).replaceAll('-', '').toLowerCase());
      expect(typed, code);
      expect(RedPosCode.verify(typed).ok, isTrue);
    });
  });

  test('Play Console legal URLs are https', () {
    expect(RedPosConfig.privacyUrl, 'https://redpos-codigos-prueba.vercel.app/privacidad.html');
    expect(RedPosConfig.termsUrl, 'https://redpos-codigos-prueba.vercel.app/terminos.html');
    expect(RedPosConfig.playMonthlyProductId, 'redpos_ads_free_monthly');
    expect(
      RedPosConfig.googleServerClientId,
      endsWith('.apps.googleusercontent.com'),
    );
  });
}
