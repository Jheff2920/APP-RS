import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../services/redpos/redpos_config.dart';
import '../services/redpos/redpos_links.dart';
import 'legal_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final whatsapp = RedPosConfig.whatsappUri;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda y soporte')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: math.min(600, constraints.maxWidth),
              height: constraints.maxHeight,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                scrollCacheExtent: const ScrollCacheExtent.pixels(280),
                children: [
                  Text(AppBrand.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Si no imprime o tienes dudas del código o la suscripción, '
                    'escríbenos. Imprimir no se bloquea sin código ni cuenta.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.email_outlined),
                          title: const Text('Correo'),
                          subtitle: Text(RedPosConfig.supportEmail),
                          onTap: () =>
                              openRedPosLink(context, RedPosConfig.mailtoUri),
                          onLongPress: () => _copy(
                            context,
                            RedPosConfig.supportEmail,
                            'Correo copiado',
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.language),
                          title: const Text('Web'),
                          subtitle: Text(RedPosConfig.siteUrl),
                          onTap: () => openRedPosLink(
                            context,
                            Uri.parse(RedPosConfig.siteUrlWithScheme),
                          ),
                        ),
                        if (whatsapp != null) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.chat_outlined),
                            title: const Text('WhatsApp'),
                            subtitle: Text(RedPosConfig.whatsappDigits),
                            onTap: () => openRedPosLink(context, whatsapp),
                          ),
                        ],
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.schedule),
                          title: const Text('Horario'),
                          subtitle: Text(RedPosConfig.supportHours),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Si no imprime', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Bluetooth, WiFi o USB bien vinculados. En Android, permiso '
                    '«Mostrar sobre otras apps» y ${AppBrand.name} activo en Ajustes → Impresión. '
                    'En IMIN, tras apagar el equipo vuelve a aceptar el permiso USB; '
                    'no hace falta volver a vincular.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text('Código y suscripción',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'El código RedPOS quita la publicidad sin iniciar sesión. '
                    'La suscripción mensual (cuenta + pago en Play) se habilitará en '
                    'una actualización; hasta entonces contáctanos o usa un código.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined),
                    title: const Text('Términos y condiciones'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalScreen.terms(),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Política de privacidad'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalScreen.privacy(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _copy(
    BuildContext context,
    String value,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
