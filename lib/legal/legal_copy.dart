import '../brand.dart';
import '../l10n/app_lang.dart';
import '../services/redpos/redpos_config.dart';

class LegalSection {
  const LegalSection(this.title, this.body);
  final String title;
  final String body;
}

/// Textos legales. Se escriben para quien usa la app: sin nombres de
/// librerías, ids de producto ni datos de compilación.
class LegalCopy {
  static String lastUpdated(L l) => l(
        '9 de octubre de 2026',
        'October 9, 2026',
      );

  static List<LegalSection> terms(L l) {
    final name = AppBrand.name;
    return [
      LegalSection(
        l('1. Qué es $name', '1. What $name is'),
        l(
          '$name es una app para imprimir en impresoras térmicas por Bluetooth, '
          'WiFi o USB. Envía a la impresora un PDF, una imagen o un XML/ZIP de '
          'SUNAT que tú o tu sistema de ventas le entregan. No es un sistema de '
          'facturación electrónica ni reemplaza a SUNAT, a tu PSE ni a tu sistema '
          'de ventas. No usa inteligencia artificial generativa ni aprendizaje '
          'automático sobre tu contenido.',
          '$name is an app for printing on thermal printers over Bluetooth, WiFi, '
          'or USB. It sends a PDF, an image, or a SUNAT XML/ZIP that you or your '
          'sales system give it to the printer. It is not an e-invoicing system and '
          'does not replace SUNAT, your PSE, or your sales system. It does not use '
          'generative AI or machine learning on your content.',
        ),
      ),
      LegalSection(
        l('2. Uso gratuito y publicidad', '2. Free use and ads'),
        l(
          'Puedes instalar e imprimir sin pagar y sin crear cuenta. Si no tienes un '
          'código de activación RedPOS, una suscripción mensual vigente ni una '
          'licencia de por vida, la app muestra avisos en pantalla y un pie breve '
          'en el papel, después del ticket y del QR. Esos avisos son de RedPOS; '
          'no usamos AdMob ni redes de anuncios de terceros.',
          'You can install and print without paying or creating an account. Without '
          'a RedPOS activation code, an active monthly subscription, or a lifetime '
          'license, the app shows notices on screen and a short footer on paper, '
          'after the ticket and QR. Those notices are RedPOS’s own; we do not use '
          'AdMob or third-party ad networks.',
        ),
      ),
      LegalSection(
        l('3. Código de activación', '3. Activation code'),
        l(
          'RedPOS entrega el código con el equipo o al contratar una licencia de '
          'por vida por correo. Es personal, de un solo uso por instalación, y no '
          'se revende. Quita la publicidad; no es un permiso extra para imprimir. '
          'Imprimir nunca se bloquea por no tener código, cuenta o internet.',
          'RedPOS provides the code with the hardware or after a lifetime license '
          'arranged by email. It is personal, single-use per install, and not for '
          'resale. It removes ads; it is not an extra permission to print. Printing '
          'is never blocked for lack of a code, an account, or internet.',
        ),
      ),
      LegalSection(
        l('4. Suscripción mensual', '4. Monthly subscription'),
        l(
          'La suscripción mensual se cobra en Google Play. Al contratarla se te pide '
          'iniciar sesión con tu cuenta de Google. Quita los avisos mientras el '
          'pago esté vigente. Si dejas de pagar, vuelven los avisos; la impresión '
          'sigue disponible. El precio lo muestra Google Play al pagar.',
          'The monthly subscription is billed through Google Play. You are asked to '
          'sign in with your Google account only when you subscribe. Ads stay off '
          'while the payment is active. If you stop paying, ads return; printing '
          'still works. Google Play shows the price at checkout.',
        ),
      ),
      LegalSection(
        l('5. Licencia de por vida', '5. Lifetime license'),
        l(
          'Puedes pedir una licencia permanente escribiendo a ${RedPosConfig.supportEmail}. '
          'El precio se acuerda por correo; no se cobra dentro de la app ni en '
          'Google Play. Te enviamos un código de activación para ese equipo y '
          'quita la publicidad para siempre en esa instalación.',
          'You can request a permanent license by writing to ${RedPosConfig.supportEmail}. '
          'The price is agreed by email; it is not charged in the app or in Google '
          'Play. We send you an activation code for that device, and it removes '
          'ads permanently on that install.',
        ),
      ),
      LegalSection(
        l('6. Responsabilidad', '6. Liability'),
        l(
          'RedPOS no responde por fallos de la impresora, del cable o USB, del '
          'Bluetooth, de tu sistema de ventas, del navegador, de SUNAT o de la red '
          'del local. En algunos equipos, Android puede volver a pedir el permiso '
          'USB después de apagarlos.',
          'RedPOS is not liable for failures of the printer, the cable or USB, '
          'Bluetooth, your sales system, the browser, SUNAT, or the local network. '
          'On some devices, Android may ask for USB permission again after they '
          'are powered off.',
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
    // Sin dirección del servidor: al usuario le basta saber qué se envía.
    final redeemHint = RedPosConfig.apiBase.trim().isEmpty
        ? l(
            'En esta versión el código se valida en tu equipo y no se envía a '
            'ningún servidor.',
            'In this version the code is checked on your device and is not sent '
            'to any server.',
          )
        : l(
            'El servicio de canje de RedPOS (conexión segura) recibe el código y, '
            'si lo indicas, un identificador de tu impresora.',
            'The RedPOS redemption service (secure connection) receives the code '
            'and, if you provide it, an identifier of your printer.',
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
          'En tu equipo (se guarda solo ahí): las impresoras que vinculas (nombre, '
          'tipo, dirección Bluetooth, IP o USB), márgenes y corte, el historial de '
          'impresiones, tus plantillas de tickets propios (con logos), los ajustes '
          'y el logo del ticket SUNAT, el código de activación, el estado de la '
          'suscripción y, si te suscribes, el correo de Google que usaste al '
          'pagar.\n\n'
          'Hacia RedPOS: solo el canje de un código de activación (el código y, '
          'si lo indicas, un identificador de la impresora). No subimos tus PDF, '
          'imágenes ni XML/ZIP a ningún servidor de RedPOS para imprimirlos.\n\n'
          'La app no incluye Firebase, Crashlytics, Google Analytics, AdMob ni '
          'herramientas de seguimiento publicitario. Los servicios de Google que '
          'sí usa (cobro de Google Play e inicio de sesión de Google) pueden enviar '
          'a Google datos técnicos propios de esos servicios, bajo la política de '
          'privacidad de Google. No hace falta una cuenta RedPOS para imprimir.',
          'On your device (stored only there): the printers you pair (name, type, '
          'Bluetooth address, IP, or USB), margins and cut, print history, your '
          'custom ticket templates (with logos), SUNAT ticket settings and logo, '
          'the activation code, subscription status and, if you subscribe, the '
          'Google email you used to pay.\n\n'
          'To RedPOS: only the redemption of an activation code (the code and, if '
          'you provide it, a printer identifier). We do not upload your PDFs, '
          'images, or XML/ZIP files to any RedPOS server in order to print them.\n\n'
          'The app does not include Firebase, Crashlytics, Google Analytics, AdMob, '
          'or ad-tracking tools. The Google services it does use (Google Play '
          'billing and Google sign-in) may send Google technical data of their own, '
          'under Google’s privacy policy. You do not need a RedPOS account to '
          'print.',
        ),
      ),
      LegalSection(
        l('3. Inteligencia artificial', '3. Artificial intelligence'),
        l(
          'Esta app no utiliza inteligencia artificial generativa ni aprendizaje '
          'automático para crear, analizar o transformar el contenido del usuario. '
          'El ajuste de imágenes para imprimir, el recorte de comprobantes y la '
          'lectura del XML de SUNAT son procesos tradicionales, no inteligencia '
          'artificial generativa.',
          'This app does not use generative artificial intelligence or machine '
          'learning to create, analyze, or transform user content. Fitting images '
          'for printing, cropping receipts, and reading SUNAT XML are traditional '
          'processes, not generative AI.',
        ),
      ),
      LegalSection(
        l('4. Servicios de terceros', '4. Third-party services'),
        l(
          'Servicios que pueden intervenir según el uso:\n'
          '• Google Play: cobra la suscripción mensual.\n'
          '• Inicio de sesión de Google: solo al contratar la suscripción; el '
          'correo puede guardarse en tu equipo.\n'
          '• Servicio de canje de códigos de RedPOS: canje del código de '
          'activación. $redeemHint\n'
          '• Correo, web y WhatsApp: se abren en sus propias apps solo cuando tú '
          'lo eliges.\n'
          '• Impresión: Bluetooth, USB o la red del local; ocurre entre tu equipo y '
          'tu impresora.\n'
          'No hay AdMob, Firebase ni analítica de terceros propia de la app. '
          'Google Play y el inicio de sesión de Google pueden enviar datos técnicos '
          'a Google (ver sección 2).',
          'Services that may be involved depending on use:\n'
          '• Google Play: bills the monthly subscription.\n'
          '• Google sign-in: only when you buy the subscription; the email may be '
          'stored on your device.\n'
          '• RedPOS activation code service: redeems the activation code. '
          '$redeemHint\n'
          '• Email, web, and WhatsApp: they open in their own apps only when you '
          'choose to.\n'
          '• Printing: Bluetooth, USB, or the local network; it happens between '
          'your device and your printer.\n'
          'No AdMob, Firebase, or app-level third-party analytics. Google Play and '
          'Google sign-in may send technical data to Google (see section 2).',
        ),
      ),
      LegalSection(
        l('5. Cuenta y pago', '5. Account and payment'),
        l(
          'Si inicias sesión y contratas la suscripción mensual, Google trata el correo '
          'o identificador de la cuenta y el estado del pago. '
          'No hace falta cuenta para imprimir ni para canjear un código. La licencia '
          'de por vida se gestiona por correo con ${RedPosConfig.supportEmail}.',
          'If you sign in and buy the monthly subscription, Google processes the '
          'account email or identifier and the payment status. No account is '
          'needed to print or redeem a code. Lifetime licenses are handled by email '
          'at ${RedPosConfig.supportEmail}.',
        ),
      ),
      LegalSection(
        l('6. Permisos', '6. Permissions'),
        l(
          'Bluetooth y ubicación (solo para buscar impresoras Bluetooth clásicas en '
          'Android 10), USB, los archivos que tú abres o compartes, y la impresión '
          'del sistema («Mostrar sobre otras apps») si quieres imprimir desde el '
          'navegador u otra app.',
          'Bluetooth and location (only to find classic Bluetooth printers on '
          'Android 10), USB, the files you open or share, and system printing '
          '(“Display over other apps”) if you print from the browser or another app.',
        ),
      ),
      LegalSection(
        l('7. Eliminación de datos', '7. Data deletion'),
        l(
          'En la app: menú Ayuda → Datos y privacidad → Borrar datos locales '
          '(impresoras, historial, plantillas, logos SUNAT, código de activación '
          'guardado y correo de Google guardado). También puedes desinstalar la '
          'app.\n\n'
          'Suscripción: Google Play → Pagos y suscripciones → cancelar '
          '(lo gestiona Google).\n\n'
          'Datos de canje en el servidor de RedPOS o solicitud formal: '
          '${RedPosConfig.deleteAccountUrl} o ${RedPosConfig.supportEmail} '
          '(asunto «Eliminar cuenta RedPOS Service»). Plazo orientativo: 30 días.',
          'In the app: Help → Data & privacy → Delete local data '
          '(printers, history, templates, SUNAT logos, saved activation code, and '
          'saved Google email). You can also uninstall the app.\n\n'
          'Subscription: Google Play → Payments & subscriptions → cancel '
          '(managed by Google).\n\n'
          'Redemption data on the RedPOS server, or a formal request: '
          '${RedPosConfig.deleteAccountUrlEn} or ${RedPosConfig.supportEmail} '
          '(subject “Delete RedPOS Service account”). Typical window: 30 days.',
        ),
      ),
      LegalSection(
        l('8. Tus derechos', '8. Your rights'),
        l(
          'Puedes acceder, rectificar o pedir el borrado de tus datos locales desde '
          'la app, y solicitar por correo el borrado de los datos de canje o '
          'contacto. '
          'Términos: ${RedPosConfig.termsUrl}. Privacidad: ${RedPosConfig.privacyUrl}. '
          'Eliminar cuenta: ${RedPosConfig.deleteAccountUrl}.',
          'You can access, correct, or delete your local data in the app, and ask '
          'by email for your redemption or contact data to be deleted. '
          'Terms: ${RedPosConfig.termsUrlEn}. Privacy: ${RedPosConfig.privacyUrlEn}. '
          'Delete account: ${RedPosConfig.deleteAccountUrlEn}.',
        ),
      ),
      LegalSection(
        l('9. Usuarios de la Unión Europea (RGPD)',
            '9. Users in the European Union (GDPR)'),
        l(
          'Si usas la app desde la Unión Europea (por ejemplo, España), esto se '
          'suma a lo anterior. El responsable es el de la sección 1.\n\n'
          '• Qué datos tratamos: casi todo se queda en tu equipo y no lo vemos. '
          'En nuestro servicio solo queda el registro de que un código de '
          'activación ya se usó (el código y la fecha) y los datos técnicos de la '
          'conexión, como la dirección IP, que el proveedor de alojamiento '
          'procesa para atender la solicitud. Si nos escribes, usamos tu correo '
          'para responderte.\n'
          '• Para qué y con qué base legal: activar el código que tú pides y '
          'evitar que se use dos veces (ejecución del servicio e interés legítimo '
          'en prevenir el fraude), y responder tus consultas.\n'
          '• Cuánto tiempo: el registro del código se conserva mientras el código '
          'siga vigente, para que no pueda reutilizarse; puedes pedir su borrado. '
          'Tus correos de soporte, el tiempo necesario para resolver tu consulta. '
          'Las solicitudes de borrado (correo y fecha), hasta 90 días.\n'
          '• Transferencias: los servidores del servicio de canje pueden estar '
          'fuera de la Unión Europea, por ejemplo en Estados Unidos.\n'
          '• Tus derechos: acceso, rectificación, supresión, limitación, '
          'oposición y portabilidad. Escríbenos a ${RedPosConfig.supportEmail} y '
          'respondemos en un máximo de 30 días. También puedes reclamar ante la '
          'autoridad de protección de datos de tu país; en España, la Agencia '
          'Española de Protección de Datos (aepd.es).\n'
          '• No tomamos decisiones automatizadas ni elaboramos perfiles sobre ti.',
          'If you use the app from the European Union (for example, Spain), this '
          'adds to the above. The controller is the one in section 1.\n\n'
          '• What data we process: almost everything stays on your device and we '
          'never see it. In our service we only keep the record that an '
          'activation code was already used (the code and the date) and '
          'technical connection data, such as the IP address, which the hosting '
          'provider processes to serve the request. If you write to us, we use '
          'your email to reply.\n'
          '• Why and legal basis: activating the code you ask for and preventing '
          'it from being used twice (performance of the service and legitimate '
          'interest in preventing fraud), and answering your questions.\n'
          '• How long: the code record is kept while the code remains valid, so it '
          'cannot be reused; you can ask for it to be deleted. Your support '
          'emails, as long as needed to resolve your question. Deletion requests '
          '(email and date), up to 90 days.\n'
          '• Transfers: the redemption service servers may be outside the '
          'European Union, for example in the United States.\n'
          '• Your rights: access, rectification, erasure, restriction, objection, '
          'and portability. Write to ${RedPosConfig.supportEmail} and we reply '
          'within 30 days. You can also complain to the data protection '
          'authority of your country; in Spain, the Spanish Data Protection '
          'Agency (aepd.es).\n'
          '• We do not make automated decisions or build profiles about you.',
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
          'En tu equipo: impresoras, historial, plantillas, logos, ajustes SUNAT y '
          'código de activación. RedPOS: solo recibe el canje del código. '
          'Google: solo si te suscribes. Tus PDF, XML e imágenes no se suben a '
          'RedPOS para imprimir. Sin AdMob, Firebase ni analítica de terceros '
          'propia; los servicios de Google (cobro de Google Play e inicio de '
          'sesión) pueden enviar datos técnicos a Google.',
          'On your device: printers, history, templates, logos, SUNAT settings, and '
          'activation code. RedPOS: only receives the code redemption. '
          'Google: only if you subscribe. Your PDFs, XML, and images are not '
          'uploaded to RedPOS to print. No AdMob, Firebase, or app-level '
          'third-party analytics; Google services (Google Play billing and '
          'sign-in) may send technical data to Google.',
        ),
      ),
      LegalSection(
        l('Inteligencia artificial', 'Artificial intelligence'),
        l(
          'Esta app no utiliza inteligencia artificial generativa ni aprendizaje '
          'automático sobre el contenido del usuario.',
          'This app does not use generative AI or machine learning on user content.',
        ),
      ),
    ];
  }

  /// Bloque «Servicios de terceros» de la pantalla Datos y privacidad.
  static LegalSection thirdParties(L l) => LegalSection(
        l('Servicios de terceros', 'Third-party services'),
        l(
          'Google Play (cobro de la suscripción), inicio de sesión de Google '
          '(solo al suscribirte) y el servicio de canje de códigos de RedPOS. '
          'Sin AdMob, Firebase, Crashlytics ni Analytics. Google Play y el inicio '
          'de sesión pueden enviar datos técnicos propios a Google.',
          'Google Play (subscription billing), Google sign-in (only when you '
          'subscribe), and the RedPOS activation code service. '
          'No AdMob, Firebase, Crashlytics, or Analytics. Google Play and sign-in '
          'may send their own technical data to Google.',
        ),
      );
}
