import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../services/printer_store.dart';
import '../theme.dart';
import 'redpos_ad_banner.dart';
import 'redpos_unlock_actions.dart';
import 'ui_kit.dart';

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
        'Función de pago. Se desbloquea con un código de activación, la '
            'suscripción mensual o la licencia de por vida.',
        'Paid feature. Unlock it with an activation code, the monthly '
            'subscription, or the lifetime license.',
      );

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.fromLTRB(14, compact ? 12 : 14, 14, compact ? 6 : 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline, size: 20, color: AppColors.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message(l),
                  style: tt.bodySmall?.copyWith(
                    color: AppColors.ink,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: EmptyMessage(
                icon: Icons.lock_outline,
                title: l('Contenido bloqueado', 'Content locked'),
                body: RedPosPaidGateBanner.message(l),
                actions: [
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await showRedPosActivateDialog(
                        context: context,
                        store: store,
                      );
                      if (ok) onUnlocked?.call();
                    },
                    icon: const Icon(Icons.vpn_key_outlined),
                    label: Text(l('Tengo un código', 'I have a code')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await openMonthlySubscription(context, store);
                      if (ok) onUnlocked?.call();
                    },
                    icon: const Icon(Icons.autorenew_rounded),
                    label: Text(
                      l('Suscripción mensual', 'Monthly subscription'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => openLifetimeLicenseMail(context),
                    child: Text(l('Licencia de por vida', 'Lifetime license')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
