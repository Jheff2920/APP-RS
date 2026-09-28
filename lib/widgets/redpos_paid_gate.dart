import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../services/printer_store.dart';
import 'redpos_ad_banner.dart';
import 'redpos_unlock_actions.dart';

/// Mensaje y acciones para desbloquear funciones de pago (mismo pase que
/// quita publicidad: código RedPOS, suscripción Play o licencia de por vida).
class RedPosPaidGateBanner extends StatelessWidget {
  const RedPosPaidGateBanner({
    super.key,
    required this.store,
    this.onUnlocked,
    this.compact = false,
  });

  final PrinterStore store;
  final VoidCallback? onUnlocked;
  final bool compact;

  static String message(L l) => l(
        'Función de pago. Necesitas un código RedPOS (código empresa), '
        'una suscripción mensual o una licencia de por vida.',
        'Paid feature. You need a RedPOS code (company code), '
        'a monthly subscription, or a lifetime license.',
      );

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, compact ? 8 : 10, 16, compact ? 8 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message(l),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () async {
                    final ok = await showRedPosActivateDialog(
                      context: context,
                      store: store,
                    );
                    if (ok) onUnlocked?.call();
                  },
                  child: Text(l('Tengo un código', 'I have a code')),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await openMonthlySubscription(context, store);
                    if (ok) onUnlocked?.call();
                  },
                  child: Text(l('Suscripción mensual', 'Monthly subscription')),
                ),
                TextButton(
                  onPressed: () => openLifetimeLicenseMail(context),
                  child: Text(l('Licencia de por vida', 'Lifetime license')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloqueo a pantalla completa (p. ej. Tickets propios).
class RedPosPaidGatePage extends StatelessWidget {
  const RedPosPaidGatePage({
    super.key,
    required this.title,
    required this.store,
    this.onUnlocked,
  });

  final String title;
  final PrinterStore store;
  final VoidCallback? onUnlocked;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 32),
          Icon(Icons.lock_outline, size: 56, color: scheme.outline),
          const SizedBox(height: 16),
          Text(
            l('Contenido bloqueado', 'Content locked'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            RedPosPaidGateBanner.message(l),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          RedPosPaidGateBanner(store: store, onUnlocked: onUnlocked),
        ],
      ),
    );
  }
}
