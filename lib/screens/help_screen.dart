import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../l10n/app_lang.dart';
import '../services/printer_store.dart';
import '../services/redpos/redpos_config.dart';
import '../services/redpos/redpos_links.dart';
import '../widgets/redpos_unlock_actions.dart';
import 'legal_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.store});

  final PrinterStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final whatsapp = RedPosConfig.whatsappUri;
    final l = L.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l('Ayuda y soporte', 'Help & support'))),
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
                    l(
                      'Si no imprime o tienes dudas del código o la suscripción, '
                      'escríbenos. Imprimir no se bloquea sin código ni cuenta.',
                      'If it does not print, or you have questions about the code '
                      'or subscription, write us. Printing is not blocked without '
                      'a code or account.',
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.email_outlined),
                          title: Text(l('Correo', 'Email')),
                          subtitle: Text(RedPosConfig.supportEmail),
                          onTap: () =>
                              openRedPosLink(context, RedPosConfig.mailtoUri),
                          onLongPress: () => _copy(
                            context,
                            RedPosConfig.supportEmail,
                            l('Correo copiado', 'Email copied'),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.language),
                          title: Text(l('Web', 'Website')),
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
                          title: Text(l('Horario', 'Hours')),
                          subtitle: Text(
                            l.english
                                ? RedPosConfig.supportHoursEn
                                : RedPosConfig.supportHours,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(l('Si no imprime', 'If it does not print'), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    l(
                      'Bluetooth, WiFi o USB bien vinculados. En Android, permiso '
                      '«Mostrar sobre otras apps» y ${AppBrand.name} activo en Ajustes → Impresión. '
                      'Tras apagar un equipo USB, vuelve a aceptar el permiso.',
                      'Pair Bluetooth, WiFi, or USB correctly. On Android, allow '
                      '“Display over other apps” and keep ${AppBrand.name} on in Settings → Printing. '
                      'After powering off a USB device, accept the USB prompt again.',
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l(
                      'Código, suscripción y licencia',
                      'Code, subscription, and license',
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l(
                      'El código RedPOS (con el equipo o por una licencia de por vida) '
                      'quita la publicidad sin iniciar sesión. La suscripción mensual '
                      'se paga en Google Play con tu cuenta Google. Si dejas de pagar '
                      'el mensual, vuelven los avisos; imprimir sigue disponible.',
                      'The RedPOS code (with the hardware or a lifetime license) '
                      'removes ads without signing in. The monthly subscription is '
                      'paid in Google Play with your Google account. If you stop the '
                      'monthly plan, ads return; printing still works.',
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: Text(l('Suscripción mensual', 'Monthly subscription')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openMonthlySubscription(context, store),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mail_outline),
                    title: Text(l('Licencia de por vida', 'Lifetime license')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openLifetimeLicenseMail(context),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined),
                    title: Text(l('Términos y condiciones', 'Terms and conditions')),
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
                    title: Text(l('Política de privacidad', 'Privacy policy')),
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
