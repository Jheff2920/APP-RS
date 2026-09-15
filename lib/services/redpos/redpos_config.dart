import '../../l10n/app_lang.dart';

/// Ajustes de la prueba RedPOS. En producción: `--dart-define` y web staff real.
class RedPosConfig {
  static const hmacSecret = String.fromEnvironment(
    'REDPOS_HMAC',
    defaultValue: 'REDPOS-PRUEBA-NO-USAR-EN-PRODUCCION',
  );

  /// Si no está vacío, la app intenta canjear el código en este servidor.
  static const apiBase = String.fromEnvironment('REDPOS_API', defaultValue: '');

  static const siteUrl = String.fromEnvironment(
    'REDPOS_SITE',
    defaultValue: 'www.redsoluciones.com.pe',
  );

  static const contactUrl = String.fromEnvironment(
    'REDPOS_CONTACT',
    defaultValue: 'https://www.redsoluciones.com.pe',
  );

  static const supportEmail = String.fromEnvironment(
    'REDPOS_SUPPORT_EMAIL',
    defaultValue: 'jcefe.2920@gmail.com',
  );

  /// Solo dígitos con código de país, ej. 51987654321. Vacío = no hay WhatsApp.
  static const whatsappDigits = String.fromEnvironment(
    'REDPOS_WHATSAPP',
    defaultValue: '',
  );

  static const supportHours = String.fromEnvironment(
    'REDPOS_SUPPORT_HOURS',
    defaultValue: 'Lunes a sábado, 9:00 a 18:00 (hora de Perú)',
  );

  static const supportHoursEn = String.fromEnvironment(
    'REDPOS_SUPPORT_HOURS_EN',
    defaultValue: 'Monday–Saturday, 9:00 a.m.–6:00 p.m. (Peru time)',
  );

  static String get siteUrlWithScheme {
    final raw = contactUrl.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://$siteUrl';
  }

  /// Términos y privacidad en HTTPS (ficha de Play).
  static const legalBase = String.fromEnvironment(
    'REDPOS_LEGAL',
    defaultValue: 'https://redpos-codigos-prueba.vercel.app',
  );

  static String get termsUrl => '$legalBase/terminos.html';
  static String get privacyUrl => '$legalBase/privacidad.html';
  static String get termsUrlEn => '$legalBase/terms.html';
  static String get privacyUrlEn => '$legalBase/privacy.html';
  static String get deleteAccountUrl => '$legalBase/eliminar-cuenta.html';
  static String get deleteAccountUrlEn => '$legalBase/delete-account.html';

  static const playMonthlyProductId = 'redpos_ads_free_monthly';

  /// ID de cliente OAuth **web** (no el secreto GOCSPX). Obligatorio en Android
  /// si no hay google-services.json. Público; no es una clave privada.
  static const googleServerClientId = String.fromEnvironment(
    'REDPOS_GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '234956126639-ciapsdg09222anujancipnd53rlm5cr1.apps.googleusercontent.com',
  );

  static Uri get mailtoUri => Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: {
          'subject': isAppEnglish
              ? 'RedPOS Service support'
              : 'Soporte RedPOS Service',
        },
      );

  static Uri get lifetimeMailtoUri {
    final subject = Uri.encodeComponent(
      isAppEnglish
          ? 'Lifetime license — RedPOS Service'
          : 'Licencia de por vida — RedPOS Service',
    );
    final body = Uri.encodeComponent(
      isAppEnglish
          ? 'Hello RedPOS,\n\n'
              'I want a permanent license to remove ads in RedPOS Service.\n\n'
              'Business name:\n'
              'City:\n\n'
              'Thank you.\n'
          : 'Hola RedPOS,\n\n'
              'Quiero una licencia permanente para quitar la publicidad en RedPOS Service.\n\n'
              'Nombre del local:\n'
              'Ciudad:\n\n'
              'Gracias.\n',
    );
    return Uri.parse('mailto:$supportEmail?subject=$subject&body=$body');
  }

  static Uri? get whatsappUri {
    final digits = whatsappDigits.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) return null;
    return Uri.parse('https://wa.me/$digits');
  }

  /// Código de demostración en esta rama de prueba.
  static const allowTestCodes = bool.fromEnvironment(
    'REDPOS_ALLOW_TEST_CODES',
    defaultValue: true,
  );

  static const testCode = 'R100301S';
}
