import '../brand.dart';
import '../services/redpos/redpos_config.dart';

class LegalSection {
  const LegalSection(this.title, this.body);
  final String title;
  final String body;
}

class LegalCopy {
  static String get lastUpdated => '10 de septiembre de 2026';

  static List<LegalSection> get terms => [
        LegalSection(
          '1. Qué es ${AppBrand.name}',
          '${AppBrand.name} es un puente de impresión térmica (Bluetooth, WiFi o USB). '
              'Envía a la impresora un PDF, imagen o XML/ZIP SUNAT que tú o tu programa '
              'de ventas le entregan. No es un sistema de facturación electrónica ni '
              'reemplaza a SUNAT, al PSE ni al POS.',
        ),
        LegalSection(
          '2. Uso gratuito y publicidad',
          'Puedes instalar e imprimir sin pagar y sin crear cuenta. Si no tienes un '
              'código de activación RedPOS ni una suscripción vigente, la app muestra '
              'avisos en pantalla y un pie breve en el papel, después del ticket y del QR.',
        ),
        LegalSection(
          '3. Código RedPOS',
          'El código lo entrega RedPOS con el equipo o al contratar. Es personal, '
              'de un solo uso por instalación, y no se revende. Quita la publicidad; '
              'no es un permiso extra para imprimir. Imprimir nunca se bloquea por no '
              'tener código, cuenta o internet.',
        ),
        LegalSection(
          '4. Suscripción',
          'La suscripción mensual (cuenta e inicio de sesión, cobro en Google Play) '
              'se habilitará en una actualización. Mientras tanto puedes quitar anuncios '
              'con un código RedPOS o escribir a ${RedPosConfig.supportEmail}. '
              'Cuando exista, si dejas de pagar volverán los avisos; la impresión seguirá disponible.',
        ),
        LegalSection(
          '5. Responsabilidad',
          'RedPOS no responde por fallos de la impresora, del cable/USB, del Bluetooth, '
              'del POS, de Chrome, de SUNAT o de la red del local. En equipos IMIN, Android '
              'puede volver a pedir permiso USB después de apagar.',
        ),
        LegalSection(
          '6. Contacto y ley aplicable',
          'Soporte: ${RedPosConfig.supportEmail} · ${RedPosConfig.siteUrlWithScheme}\n'
              '${RedPosConfig.supportHours}\n'
              'Estos términos se rigen por las leyes de la República del Perú. '
              'RedPOS puede actualizarlos; la fecha de la versión aparece al inicio.',
        ),
      ];

  static List<LegalSection> get privacy => [
        LegalSection(
          '1. Responsable',
          'RedPOS trata los datos de ${AppBrand.name}. Contacto: '
              '${RedPosConfig.supportEmail} · ${RedPosConfig.siteUrlWithScheme}.',
        ),
        LegalSection(
          '2. Qué se guarda en el aparato',
          'Impresoras vinculadas (nombre, tipo, dirección Bluetooth/MAC, IP, USB), '
              'ajustes de papel y corte, historial local de trabajos e, si activas un código, '
              'un pase de licencia en el teléfono. Eso queda en el dispositivo.',
        ),
        LegalSection(
          '3. Qué no hacemos',
          '${AppBrand.name} no sube a un servidor de RedPOS el PDF, la imagen ni el XML '
              'de la boleta para imprimir. La impresión sale del teléfono o tablet hacia '
              'la impresora. Un código de activación puede enviarse a nuestro servidor '
              'solo para canjearlo, cuando esa validación esté en producción.',
        ),
        LegalSection(
          '4. Cuenta y pago',
          'Si más adelante inicias sesión y contratas una suscripción, se tratarán '
              'el correo o identificador de la cuenta y el estado del pago (Google Play). '
              'No hace falta cuenta para imprimir.',
        ),
        LegalSection(
          '5. Permisos',
          'Bluetooth y ubicación (solo para buscar impresoras Classic en Android 10), '
              'USB, archivos que tú abres o compartes, e impresión del sistema '
              '(«Mostrar sobre otras apps») si quieres imprimir desde Chrome u otra app.',
        ),
        LegalSection(
          '6. Tus derechos',
          'Puedes borrar impresoras e historial desde la app, o desinstalarla. '
              'Para preguntas sobre datos: ${RedPosConfig.supportEmail}.',
        ),
      ];
}
