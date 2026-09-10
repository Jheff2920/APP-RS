import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../brand.dart';
import '../legal/legal_copy.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen.terms({super.key}) : privacy = false;
  const LegalScreen.privacy({super.key}) : privacy = true;

  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = privacy ? 'Privacidad' : 'Términos y condiciones';
    final sections = privacy ? LegalCopy.privacy : LegalCopy.terms;

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
                    'Última actualización: ${LegalCopy.lastUpdated}',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    privacy
                        ? 'Cómo ${AppBrand.name} usa datos en el teléfono y, más adelante, en una cuenta.'
                        : 'Uso de ${AppBrand.name}. Esto no sustituye asesoría legal; revísalo antes de Play.',
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
