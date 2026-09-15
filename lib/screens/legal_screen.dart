import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../brand.dart';
import '../l10n/app_lang.dart';
import '../legal/legal_copy.dart';

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
                  Text(
                    l('Última actualización: ${LegalCopy.lastUpdated(l)}',
                        'Last updated: ${LegalCopy.lastUpdated(l)}'),
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
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
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  for (final section in sections) ...[
                    Text(section.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(section.body, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
