import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../l10n/app_lang.dart';
import '../legal/legal_copy.dart';
import '../services/printer_store.dart';
import '../services/privacy_data_wipe.dart';
import '../services/redpos/redpos_config.dart';
import '../services/redpos/redpos_links.dart';
import 'legal_screen.dart';

/// Pantalla Play-facing: resumen de datos, IA, terceros, política y borrado.
class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key, required this.store});

  final PrinterStore store;

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  var _wiping = false;

  Future<void> _confirmWipe() async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final loc = L.of(ctx);
        return AlertDialog(
          title: Text(loc('Borrar datos locales', 'Delete local data')),
          content: Text(
            loc(
              'Se borrarán impresoras vinculadas, historial, plantillas de tickets '
              'propios, logo/ajustes SUNAT, pase de licencia local y el correo de '
              'Google guardado en este aparato.\n\n'
              'No cancela la suscripción de Google Play ni borra el canje del código '
              'en el servidor RedPOS. Para eso usa los enlaces de esta pantalla.',
              'This will delete paired printers, history, custom ticket templates, '
              'SUNAT logo/settings, the local license pass, and the Google email '
              'stored on this device.\n\n'
              'It does not cancel the Google Play subscription or remove code '
              'redemption on the RedPOS server. Use the links on this screen for that.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc('Cancelar', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc('Borrar', 'Delete')),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _wiping = true);
    final result = await PrivacyDataWipe(printerStore: widget.store).wipeLocal();
    if (!mounted) return;
    setState(() => _wiping = false);
    final messenger = ScaffoldMessenger.of(context);
    if (result.ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l(
              'Datos locales borrados. Reinicia la app si la lista no se actualiza.',
              'Local data deleted. Restart the app if the list does not refresh.',
            ),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l(
              'No se pudo completar el borrado: ${result.message ?? "error"}',
              'Could not finish deletion: ${result.message ?? "error"}',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = L.of(context);
    final summary = LegalCopy.privacySummary(l);
    final privacyUrl = l.english
        ? RedPosConfig.privacyUrlEn
        : RedPosConfig.privacyUrl;
    final deleteUrl = l.english
        ? RedPosConfig.deleteAccountUrlEn
        : RedPosConfig.deleteAccountUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(l('Datos y privacidad', 'Data & privacy')),
      ),
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
                      'Transparencia para Play y usuarios: qué se guarda, qué no, '
                      'terceros y cómo borrar datos.',
                      'Play and user transparency: what is stored, what is not, '
                      'third parties, and how to delete data.',
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l(
                      'Última actualización: ${LegalCopy.lastUpdated(l)}',
                      'Last updated: ${LegalCopy.lastUpdated(l)}',
                    ),
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 16),
                  for (final section in summary) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(section.title, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(section.body, style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l('Terceros y APIs', 'Third parties and APIs'),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l(
                              'Google Play Billing, Google Sign-In (solo al suscribirte), '
                              'API de códigos RedPOS (canje), url_launcher, plugins '
                              'locales de impresión y SharedPreferences. '
                              'Sin AdMob, Firebase, Crashlytics ni Analytics.',
                              'Google Play Billing, Google Sign-In (subscribe only), '
                              'RedPOS codes API (redemption), url_launcher, local print '
                              'plugins, and SharedPreferences. '
                              'No AdMob, Firebase, Crashlytics, or Analytics.',
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l('Política y enlaces', 'Policy and links'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: Text(
                            l('Política de privacidad (completa)', 'Full privacy policy'),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LegalScreen.privacy(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.open_in_browser),
                          title: Text(
                            l('Abrir política en el navegador', 'Open policy in browser'),
                          ),
                          subtitle: Text(privacyUrl),
                          onTap: () => openRedPosLink(
                            context,
                            Uri.parse(privacyUrl),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.article_outlined),
                          title: Text(
                            l('Términos y condiciones', 'Terms and conditions'),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LegalScreen.terms(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l('Eliminar datos', 'Delete data'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: _wiping
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  Icons.delete_forever_outlined,
                                  color: theme.colorScheme.error,
                                ),
                          title: Text(
                            l('Borrar datos locales', 'Delete local data'),
                          ),
                          subtitle: Text(
                            l(
                              'Impresoras, historial, plantillas, logos, licencia local',
                              'Printers, history, templates, logos, local license',
                            ),
                          ),
                          onTap: _wiping ? null : _confirmWipe,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.manage_accounts_outlined),
                          title: Text(
                            l(
                              'Solicitar borrado en servidor / cuenta',
                              'Request server / account deletion',
                            ),
                          ),
                          subtitle: Text(deleteUrl),
                          onTap: () => openRedPosLink(
                            context,
                            Uri.parse(deleteUrl),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.email_outlined),
                          title: Text(
                            l('Escribir a soporte', 'Email support'),
                          ),
                          subtitle: Text(RedPosConfig.supportEmail),
                          onTap: () => openRedPosLink(
                            context,
                            Uri(
                              scheme: 'mailto',
                              path: RedPosConfig.supportEmail,
                              queryParameters: {
                                'subject': l.english
                                    ? 'Delete RedPOS Service account'
                                    : 'Eliminar cuenta RedPOS Service',
                              },
                            ),
                          ),
                          onLongPress: () async {
                            await Clipboard.setData(
                              ClipboardData(text: RedPosConfig.supportEmail),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l('Correo copiado', 'Email copied'),
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.subscriptions_outlined),
                          title: Text(
                            l(
                              'Cancelar suscripción en Google Play',
                              'Cancel subscription in Google Play',
                            ),
                          ),
                          subtitle: Text(
                            l(
                              'Play Store → Pagos y suscripciones',
                              'Play Store → Payments & subscriptions',
                            ),
                          ),
                          onTap: () => openRedPosLink(
                            context,
                            Uri.parse(
                              'https://play.google.com/store/account/subscriptions',
                            ),
                          ),
                        ),
                      ],
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
}
