import '../brand.dart';
import '../l10n/app_lang.dart';
import '../services/redpos/redpos_config.dart';

class LegalSection {
  const LegalSection(this.title, this.body);
  final String title;
  final String body;
}

class LegalCopy {
  static String lastUpdated(L l) => l(
        '28 de septiembre de 2026',
        'September 28, 2026',
      );

  static List<LegalSection> terms(L l) {
    final name = AppBrand.name;
    return [
      LegalSection(
        l('1. Qué es $name', '1. What $name is'),
        l(
          '$name es un puente de impresión térmica (Bluetooth, WiFi o USB). '
          'Envía a la impresora un PDF, imagen o XML/ZIP SUNAT que tú o tu programa '
          'de ventas le entregan. No es un sistema de facturación electrónica ni '
          'reemplaza a SUNAT, al PSE ni al POS. No utiliza inteligencia artificial '
          'generativa ni modelos de aprendizaje automático sobre el contenido del usuario.',
          '$name is a thermal print bridge (Bluetooth, WiFi, or USB). It sends a PDF, '
          'image, or SUNAT XML/ZIP from you or your POS to the printer. It is not an '
          'e-invoicing system and does not replace SUNAT, a PSE, or your POS. It does '
          'not use generative AI or machine-learning models on user content.',
        ),
      ),
      LegalSection(
        l('2. Uso gratuito y publicidad', '2. Free use and ads'),
        l(
          'Puedes instalar e imprimir sin pagar y sin crear cuenta. Si no tienes un '
          'código de activación RedPOS, una suscripción mensual vigente ni una '
          'licencia de por vida, la app muestra avisos en pantalla y un pie breve '
          'en el papel, después del ticket y del QR. Esos avisos son de RedPOS '
          '(primera parte); no usamos AdMob ni redes de anuncios de terceros.',
          'You can install and print without paying or creating an account. Without a '
          'RedPOS activation code, an active monthly subscription, or a lifetime '
          'license, the app shows on-screen notices and a short footer on paper, '
          'after the ticket and QR. Those notices are first-party RedPOS ads; we do '
          'not use AdMob or third-party ad networks.',
        ),
      ),
      LegalSection(
        l('3. Código RedPOS', '3. RedPOS code'),
        l(
          'El código lo entrega RedPOS con el equipo o al contratar una licencia de '
          'por vida por correo. Es personal, de un solo uso por instalación, y no '
          'se revende. Quita la publicidad; no es un permiso extra para imprimir. '
          'Imprimir nunca se bloquea por no tener código, cuenta o internet.',
          'RedPOS provides the code with the hardware or after a lifetime license '
          'arranged by email. It is personal, one-time per install, and not for resale. '
          'It removes ads; it is not an extra print license. Printing is never blocked '
          'for lack of a code, account, or internet.',
        ),
      ),
      LegalSection(
        l('4. Suscripción mensual', '4. Monthly subscription'),
        l(
          'La suscripción mensual se cobra en Google Play. Al contratarla se te pide '
          'iniciar sesión con tu cuenta de Google. Quita los avisos mientras el '
          'pago esté vigente. Si dejas de pagar, vuelven los avisos; la impresión '
          'sigue disponible. El precio lo muestra Play al pagar.',
          'The monthly subscription is billed through Google Play. Signing in with '
          'Google is required only when you subscribe. Ads stay off while the payment '
          'is active. If you stop paying, ads return; printing still works. Play shows '
          'the price at checkout.',
        ),
      ),
      LegalSection(
        l('5. Licencia de por vida', '5. Lifetime license'),
        l(
          'Puedes pedir una licencia permanente escribiendo a ${RedPosConfig.supportEmail}. '
          'El precio se acuerda por correo; no se cobra dentro de la app ni de Play. '
          'Te enviamos un código RedPOS para activar en el teléfono. El mismo código '
          'quita la publicidad para siempre en esa instalación.',
          'You can request a permanent license at ${RedPosConfig.supportEmail}. The '
          'price is agreed by email; it is not charged in the app or Play. We send a '
          'RedPOS code to activate on the device. That code removes ads permanently '
          'on that install.',
        ),
      ),
      LegalSection(
        l('6. Responsabilidad', '6. Liability'),
        l(
          'RedPOS no responde por fallos de la impresora, del cable/USB, del Bluetooth, '
          'del POS, de Chrome, de SUNAT o de la red del local. En equipos IMIN, Android '
          'puede volver a pedir permiso USB después de apagar.',
          'RedPOS is not liable for printer, cable/USB, Bluetooth, POS, Chrome, SUNAT, '
          'or venue network failures. On IMIN devices, Android may ask for USB permission '
          'again after power-off.',
        ),
      ),
      LegalSection(
        l('7. Contacto y ley aplicable', '7. Contact and governing law'),
        l(
          'Soporte: ${RedPosConfig.supportEmail} · ${RedPosConfig.siteUrlWithScheme}\n'
          '${RedPosConfig.supportHours}\n'
          'Estos términos se rigen por las leyes de la República del Perú. '
          'RedPOS puede actualizarlos; la fecha de la versión aparece al inicio.',
          'Support: ${RedPosConfig.supportEmail} · ${RedPosConfig.siteUrlWithScheme}\n'
          '${RedPosConfig.supportHoursEn}\n'
          'These terms are governed by the laws of the Republic of Peru. '
          'RedPOS may update them; the version date is at the top.',
        ),
      ),
    ];
  }

  static List<LegalSection> privacy(L l) {
    final name = AppBrand.name;
    final apiHint = RedPosConfig.apiBase.trim().isEmpty
        ? l(
            'Cuando la validación remota está activa (URL de API RedPOS configurada '
            'en la compilación), el código y un identificador de impresora opcional '
            'se envían solo para canjearlo.',
            'When remote validation is enabled (RedPOS API URL set at build time), '
            'the code and an optional printer identifier are sent only to redeem it.',
          )
        : l(
            'El servidor de canje de códigos RedPOS recibe el código y, si lo indicas, '
            'un identificador de impresora. URL base de API: ${RedPosConfig.apiBase}.',
            'The RedPOS code-redemption server receives the code and, if provided, a '
            'printer identifier. API base URL: ${RedPosConfig.apiBase}.',
          );
    return [
      LegalSection(
        l('1. Responsable', '1. Controller'),
        l(
          'RedPOS (marca de Red Soluciones / redsoluciones.com.pe) trata los datos '
          'de $name. Contacto: ${RedPosConfig.supportEmail} · '
          '${RedPosConfig.siteUrlWithScheme}.',
          'RedPOS (Red Soluciones / redsoluciones.com.pe) processes $name data. '
          'Contact: ${RedPosConfig.supportEmail} · ${RedPosConfig.siteUrlWithScheme}.',
        ),
      ),
      LegalSection(
        l('2. Qué se recoge y qué no', '2. What is and is not collected'),
        l(
          'En el aparato (local): impresoras vinculadas (nombre, tipo, Bluetooth/MAC, '
          'IP, USB), márgenes y corte, historial local de trabajos, plantillas de '
          'tickets propios (incl. logos), ajustes y logo del ticket SUNAT, pase de '
          'licencia/código, estado de suscripción Play y, si te suscribes, el correo '
          'de Google usado al pagar.\n\n'
          'Hacia RedPOS: solo el canje de un código de activación cuando hay API '
          'configurada (código + dato opcional de impresora). No subimos el PDF, la '
          'imagen ni el XML/ZIP de la boleta a un servidor de RedPOS para imprimir.\n\n'
          'La app no incluye SDK de Firebase, Crashlytics, Google Analytics ni AdMob, '
          'ni kits de seguimiento publicitario. Los servicios de Google que sí usa '
          '(Google Play Billing y Google Sign-In) pueden enviar a Google telemetría '
          'técnica propia de esos servicios (p. ej. diagnóstico de la librería de '
          'facturación), regida por la política de privacidad de Google. '
          'No hay cuenta RedPOS obligatoria para imprimir.',
          'On device (local): paired printers (name, type, Bluetooth/MAC, IP, USB), '
          'margins and cut, local job history, custom ticket templates (incl. logos), '
          'SUNAT ticket settings and logo, license/code pass, Play subscription status, '
          'and, if you subscribe, the Google email used at checkout.\n\n'
          'To RedPOS: only activation-code redemption when an API is configured '
          '(code + optional printer id). We do not upload the receipt PDF, image, or '
          'XML/ZIP to a RedPOS server to print.\n\n'
          'The app does not include Firebase, Crashlytics, Google Analytics, AdMob, or '
          'ad-tracking SDKs. The Google services it does use (Google Play Billing and '
          'Google Sign-In) may send Google technical telemetry of their own (e.g. '
          'billing library diagnostics), governed by Google’s privacy policy. '
          'No RedPOS account is required to print.',
        ),
      ),
      LegalSection(
        l('3. Inteligencia artificial', '3. Artificial intelligence'),
        l(
          'Esta app no utiliza inteligencia artificial generativa ni modelos de '
          'aprendizaje automático (ML) para crear, analizar o transformar el contenido '
          'del usuario. El raster ESC/POS, el recorte de vouchers y el parseo XML SUNAT '
          'son algoritmos tradicionales de imagen y texto, no IA generativa.',
          'This app does not use generative artificial intelligence or machine-learning '
          '(ML) models to create, analyze, or transform user content. ESC/POS raster, '
          'voucher cropping, and SUNAT XML parsing are traditional image/text algorithms, '
          'not generative AI.',
        ),
      ),
      LegalSection(
        l('4. Terceros y APIs', '4. Third parties and APIs'),
        l(
          'Servicios y SDKs que pueden intervenir según el uso:\n'
          '• Google Play Billing (in_app_purchase) — suscripción mensual '
          '${RedPosConfig.playMonthlyProductId}.\n'
          '• Google Sign-In — solo al contratar la suscripción; el correo puede '
          'guardarse en el aparato.\n'
          '• API de códigos RedPOS (HTTPS, p. ej. redpos-codigos-prueba.vercel.app) — '
          'canje de código. $apiHint\n'
          '• url_launcher — abrir correo, web o WhatsApp que tú eliges.\n'
          '• Plugins locales de impresión: Bluetooth, USB, red TCP :9100, PDF/imagen '
          '(esc_pos_utils_plus, print_bluetooth_thermal, pdfx, image, etc.).\n'
          '• SharedPreferences — almacenamiento local.\n'
          'No hay AdMob ni SDK de Firebase ni analítica de terceros propia de la app. '
          'Google Play Billing y Google Sign-In pueden enviar telemetría técnica a '
          'Google (ver sección 2).',
          'Services and SDKs that may be involved depending on use:\n'
          '• Google Play Billing (in_app_purchase) — monthly subscription '
          '${RedPosConfig.playMonthlyProductId}.\n'
          '• Google Sign-In — only when buying the subscription; the email may be '
          'stored on device.\n'
          '• RedPOS codes API (HTTPS, e.g. redpos-codigos-prueba.vercel.app) — code '
          'redemption. $apiHint\n'
          '• url_launcher — open mail, web, or WhatsApp you choose.\n'
          '• Local print plugins: Bluetooth, USB, TCP :9100, PDF/image '
          '(esc_pos_utils_plus, print_bluetooth_thermal, pdfx, image, etc.).\n'
          '• SharedPreferences — local storage.\n'
          'No AdMob, Firebase SDK, or app-level third-party analytics. '
          'Google Play Billing and Google Sign-In may send technical telemetry to '
          'Google (see section 2).',
        ),
      ),
      LegalSection(
        l('5. Cuenta y pago', '5. Account and payment'),
        l(
          'Si inicias sesión y contratas la suscripción mensual, Google trata el correo '
          'o identificador de la cuenta y el estado del pago (Google Play Billing). '
          'No hace falta cuenta para imprimir ni para canjear un código. La licencia '
          'de por vida se gestiona por correo con ${RedPosConfig.supportEmail}.',
          'If you sign in and buy the monthly subscription, Google processes the account '
          'email or identifier and payment status (Google Play Billing). No account is '
          'needed to print or redeem a code. Lifetime licenses are handled by email at '
          '${RedPosConfig.supportEmail}.',
        ),
      ),
      LegalSection(
        l('6. Permisos', '6. Permissions'),
        l(
          'Bluetooth y ubicación (solo para buscar impresoras Classic en Android 10), '
          'USB, archivos que tú abres o compartes, e impresión del sistema '
          '(«Mostrar sobre otras apps») si quieres imprimir desde Chrome u otra app.',
          'Bluetooth and location (only to scan Classic printers on Android 10), USB, '
          'files you open or share, and system printing (“Display over other apps”) if '
          'you print from Chrome or another app.',
        ),
      ),
      LegalSection(
        l('7. Eliminación de datos', '7. Data deletion'),
        l(
          'En la app: menú Ayuda → Datos y privacidad → Borrar datos locales '
          '(impresoras, historial, plantillas, logos SUNAT, pase de licencia local y '
          'correo Google guardado). También puedes desinstalar la app.\n\n'
          'Suscripción Play: Google Play → Pagos y suscripciones → cancelar '
          '(lo gestiona Google).\n\n'
          'Datos de canje en servidor RedPOS o solicitud formal: '
          '${RedPosConfig.deleteAccountUrl} o ${RedPosConfig.supportEmail} '
          '(asunto «Eliminar cuenta RedPOS Service»). Plazo orientativo: 30 días.',
          'In the app: Help → Data & privacy → Delete local data '
          '(printers, history, templates, SUNAT logos, local license pass, and stored '
          'Google email). You can also uninstall the app.\n\n'
          'Play subscription: Google Play → Payments & subscriptions → cancel '
          '(managed by Google).\n\n'
          'Server-side code redemption or a formal request: '
          '${RedPosConfig.deleteAccountUrlEn} or ${RedPosConfig.supportEmail} '
          '(subject “Delete RedPOS Service account”). Typical window: 30 days.',
        ),
      ),
      LegalSection(
        l('8. Tus derechos', '8. Your rights'),
        l(
          'Puedes acceder, rectificar o pedir el borrado de datos locales desde la app, '
          'y solicitar el borrado de datos de canje/contacto por correo. '
          'Términos: ${RedPosConfig.termsUrl}. Privacidad: ${RedPosConfig.privacyUrl}. '
          'Eliminar cuenta: ${RedPosConfig.deleteAccountUrl}.',
          'You can access, correct, or delete local data in the app, and request '
          'deletion of redemption/contact data by email. '
          'Terms: ${RedPosConfig.termsUrlEn}. Privacy: ${RedPosConfig.privacyUrlEn}. '
          'Delete account: ${RedPosConfig.deleteAccountUrlEn}.',
        ),
      ),
    ];
  }

  /// Resumen corto para la pantalla Datos y privacidad.
  static List<LegalSection> privacySummary(L l) {
    return [
      LegalSection(
        l('Resumen de datos', 'Data summary'),
        l(
          'Local: impresoras, historial, plantillas, logos, ajustes SUNAT, licencia. '
          'RedPOS: solo canje de código (si hay API). Google: solo si te suscribes. '
          'Tickets PDF/XML/imagen no se suben a RedPOS para imprimir. '
          'Sin AdMob, SDK de Firebase ni analítica de terceros propia; los servicios '
          'de Google (Play Billing, Sign-In) pueden enviar telemetría técnica a Google.',
          'Local: printers, history, templates, logos, SUNAT settings, license. '
          'RedPOS: code redemption only (if API enabled). Google: only if you subscribe. '
          'PDF/XML/image tickets are not uploaded to RedPOS to print. '
          'No AdMob, Firebase SDK, or app-level third-party analytics; Google services '
          '(Play Billing, Sign-In) may send technical telemetry to Google.',
        ),
      ),
      LegalSection(
        l('Inteligencia artificial', 'Artificial intelligence'),
        l(
          'Esta app no utiliza inteligencia artificial generativa ni ML sobre el '
          'contenido del usuario.',
          'This app does not use generative AI or ML on user content.',
        ),
      ),
    ];
  }
}
