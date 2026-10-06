import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../l10n/app_lang.dart';
import '../legal/legal_copy.dart';
import '../services/printer_store.dart';
import '../services/privacy_data_wipe.dart';
import '../services/redpos/redpos_config.dart';
import '../services/redpos/redpos_links.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';
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
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
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

    Widget block(String title, String body) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.inkSoft),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(l('Datos y privacidad', 'Data & privacy')),
      ),
      body: PageList(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l(
                    'Qué guarda ${AppBrand.name}, qué no, con quién se '
                        'comparte y cómo borrarlo.',
                    'What ${AppBrand.name} stores, what it does not, who it '
                        'is shared with, and how to delete it.',
                  ),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 4),
                Text(
                  l(
                    'Última actualización: ${LegalCopy.lastUpdated(l)}',
                    'Last updated: ${LegalCopy.lastUpdated(l)}',
                  ),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          SectionLabel(l('Resumen', 'Summary')),
          SectionGroup(
            children: [
              for (final section in summary) block(section.title, section.body),
              block(
                l('Terceros y APIs', 'Third parties and APIs'),
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
              ),
            ],
          ),
          SectionLabel(l('Política y enlaces', 'Policy and links')),
          SectionGroup(
            dividerIndent: 68,
            children: [
              NavRow(
                icon: Icons.privacy_tip_outlined,
                title: l('Política de privacidad (completa)', 'Full privacy policy'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalScreen.privacy(),
                  ),
                ),
              ),
              NavRow(
                icon: Icons.open_in_browser_rounded,
                title: l('Abrir política en el navegador', 'Open policy in browser'),
                subtitle: privacyUrl,
                onTap: () => openRedPosLink(context, Uri.parse(privacyUrl)),
              ),
              NavRow(
                icon: Icons.article_outlined,
                title: l('Términos y condiciones', 'Terms and conditions'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalScreen.terms(),
                  ),
                ),
              ),
            ],
          ),
          SectionLabel(l('Eliminar datos', 'Delete data')),
          SectionGroup(
            dividerIndent: 68,
            children: [
              NavRow(
                icon: Icons.delete_forever_outlined,
                destructive: true,
                title: l('Borrar datos locales', 'Delete local data'),
                subtitle: l(
                  'Impresoras, historial, plantillas, logos y licencia local',
                  'Printers, history, templates, logos and local license',
                ),
                trailing: _wiping ? const ButtonSpinner() : null,
                showChevron: false,
                onTap: _wiping ? null : _confirmWipe,
              ),
              NavRow(
                icon: Icons.manage_accounts_outlined,
                title: l(
                  'Solicitar borrado en servidor o cuenta',
                  'Request server or account deletion',
                ),
                subtitle: deleteUrl,
                onTap: () => openRedPosLink(context, Uri.parse(deleteUrl)),
              ),
              NavRow(
                icon: Icons.mail_outline_rounded,
                title: l('Escribir a soporte', 'Email support'),
                subtitle: RedPosConfig.supportEmail,
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
                    SnackBar(content: Text(l('Correo copiado', 'Email copied'))),
                  );
                },
              ),
              NavRow(
                icon: Icons.subscriptions_outlined,
                title: l(
                  'Cancelar suscripción en Google Play',
                  'Cancel subscription in Google Play',
                ),
                subtitle: l(
                  'Play Store, Pagos y suscripciones',
                  'Play Store, Payments & subscriptions',
                ),
                onTap: () => openRedPosLink(
                  context,
                  Uri.parse('https://play.google.com/store/account/subscriptions'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
