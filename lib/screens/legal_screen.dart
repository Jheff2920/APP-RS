import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/app_lang.dart';
import '../legal/legal_copy.dart';
import '../services/redpos/redpos_config.dart';
import '../services/redpos/redpos_links.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen.terms({super.key}) : privacy = false;
  const LegalScreen.privacy({super.key}) : privacy = true;

  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = L.of(context);
    final title = privacy
        ? l('Privacidad', 'Privacy')
        : l('Términos y condiciones', 'Terms and conditions');
    final sections = privacy ? LegalCopy.privacy(l) : LegalCopy.terms(l);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PageList(
        maxWidth: 680,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    privacy
                        ? l(
                            'Cómo ${AppBrand.name} usa datos en el teléfono y, si te suscribes, en Google Play.',
                            'How ${AppBrand.name} uses data on the phone and, if you subscribe, in Google Play.',
                          )
                        : l(
                            'Uso de ${AppBrand.name}. Imprimir no se bloquea sin cuenta.',
                            'Using ${AppBrand.name}. Printing is not blocked without an account.',
                          ),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l('Última actualización: ${LegalCopy.lastUpdated(l)}',
                        'Last updated: ${LegalCopy.lastUpdated(l)}'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.inkSoft),
                  ),
                  if (privacy) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: () {
                            final url = l.english
                                ? RedPosConfig.privacyUrlEn
                                : RedPosConfig.privacyUrl;
                            openRedPosLink(context, Uri.parse(url));
                          },
                          icon: const Icon(Icons.open_in_browser_rounded),
                          label: Text(
                            l('Abrir en el navegador', 'Open in browser'),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final url = l.english
                                ? RedPosConfig.deleteAccountUrlEn
                                : RedPosConfig.deleteAccountUrl;
                            openRedPosLink(context, Uri.parse(url));
                          },
                          child: Text(
                            l('Eliminar cuenta o datos', 'Delete account or data'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 16),
                  for (final section in sections) ...[
                    Text(section.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      section.body,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
