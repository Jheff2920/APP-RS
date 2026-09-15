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
        '14 de septiembre de 2026',
        'September 14, 2026',
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
          'reemplaza a SUNAT, al PSE ni al POS.',
          '$name is a thermal print bridge (Bluetooth, WiFi, or USB). It sends a PDF, '
          'image, or SUNAT XML/ZIP from you or your POS to the printer. It is not an '
          'e-invoicing system and does not replace SUNAT, a PSE, or your POS.',
        ),
      ),
      LegalSection(
        l('2. Uso gratuito y publicidad', '2. Free use and ads'),
        l(
          'Puedes instalar e imprimir sin pagar y sin crear cuenta. Si no tienes un '
          'código de activación RedPOS, una suscripción mensual vigente ni una '
          'licencia de por vida, la app muestra avisos en pantalla y un pie breve '
          'en el papel, después del ticket y del QR.',
          'You can install and print without paying or creating an account. Without a '
          'RedPOS activation code, an active monthly subscription, or a lifetime '
          'license, the app shows on-screen notices and a short footer on paper, '
          'after the ticket and QR.',
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
    return [
      LegalSection(
        l('1. Responsable', '1. Controller'),
        l(
          'RedPOS trata los datos de $name. Contacto: '
          '${RedPosConfig.supportEmail} · ${RedPosConfig.siteUrlWithScheme}.',
          'RedPOS processes $name data. Contact: '
          '${RedPosConfig.supportEmail} · ${RedPosConfig.siteUrlWithScheme}.',
        ),
      ),
      LegalSection(
        l('2. Qué se guarda en el aparato', '2. What stays on the device'),
        l(
          'Impresoras vinculadas (nombre, tipo, dirección Bluetooth/MAC, IP, USB), '
          'ajustes de papel y corte, historial local de trabajos e, si activas un código '
          'o una suscripción, un pase de licencia en el teléfono. Eso queda en el dispositivo.',
          'Paired printers (name, type, Bluetooth/MAC address, IP, USB), paper and cut '
          'settings, local job history, and, if you redeem a code or subscribe, a license '
          'pass on the phone. That stays on the device.',
        ),
      ),
      LegalSection(
        l('3. Qué no hacemos', '3. What we do not do'),
        l(
          '$name no sube a un servidor de RedPOS el PDF, la imagen ni el XML '
          'de la boleta para imprimir. La impresión sale del teléfono o tablet hacia '
          'la impresora. Un código de activación puede enviarse a nuestro servidor '
          'solo para canjearlo, cuando esa validación esté en producción.',
          '$name does not upload the receipt PDF, image, or XML to a RedPOS server '
          'to print. Printing goes from the phone or tablet to the printer. An activation '
          'code may be sent to our server only to redeem it, when that check is in production.',
        ),
      ),
      LegalSection(
        l('4. Cuenta y pago', '4. Account and payment'),
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
        l('5. Permisos', '5. Permissions'),
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
        l('6. Tus derechos', '6. Your rights'),
        l(
          'Puedes borrar impresoras e historial desde la app, o desinstalarla. '
          'Para preguntas sobre datos: ${RedPosConfig.supportEmail}. '
          'Términos: ${RedPosConfig.termsUrl}. Privacidad: ${RedPosConfig.privacyUrl}.',
          'You can delete printers and history in the app, or uninstall it. '
          'Data questions: ${RedPosConfig.supportEmail}. '
          'Terms: ${RedPosConfig.termsUrlEn}. Privacy: ${RedPosConfig.privacyUrlEn}.',
        ),
      ),
    ];
  }
}
