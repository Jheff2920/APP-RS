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
    defaultValue: 'www.redpos.com',
  );

  static const contactUrl = String.fromEnvironment(
    'REDPOS_CONTACT',
    defaultValue: 'https://www.redpos.com',
  );

  static const supportEmail = String.fromEnvironment(
    'REDPOS_SUPPORT_EMAIL',
    defaultValue: 'soporte@redpos.com',
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

  static String get siteUrlWithScheme {
    final raw = contactUrl.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://$siteUrl';
  }

  static Uri get mailtoUri => Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: const {'subject': 'Soporte RedPOS Service'},
      );

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
