import 'package:flutter_test/flutter_test.dart';
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
    expect(uri.toString(), contains('Licencia'));
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
