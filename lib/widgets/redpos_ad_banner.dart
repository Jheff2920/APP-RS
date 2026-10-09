import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../services/printer_store.dart';
import '../services/redpos/redpos_license.dart';
import '../theme.dart';
import 'redpos_unlock_actions.dart';
import 'ui_kit.dart';

/// Aviso compacto de versión gratuita; "Quitar publicidad" abre las opciones.
class RedPosAdBanner extends StatelessWidget {
  const RedPosAdBanner({
    super.key,
    required this.adsFree,
    required this.store,
    this.onActivated,
  });

  final bool adsFree;
  final PrinterStore store;
  final VoidCallback? onActivated;

  @override
  Widget build(BuildContext context) {
    if (adsFree) return const SizedBox.shrink();
    final l = L.of(context);
    final tt = Theme.of(context).textTheme;
    return Card(
      color: AppColors.warnSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.warn.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            const IconTile(
              icon: Icons.campaign_outlined,
              color: AppColors.warn,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l('Versión gratuita', 'Free version'),
                    style: tt.titleSmall?.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l(
                      'Cada ticket sale con un pie de publicidad.',
                      'Each ticket prints with an ad footer.',
                    ),
                    style: tt.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.warn),
              onPressed: () => showUnlockOptionsSheet(
                context: context,
                store: store,
                onActivated: onActivated,
              ),
              child: Text(l('Quitar', 'Remove')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja inferior con las tres formas de desbloquear.
Future<void> showUnlockOptionsSheet({
  required BuildContext context,
  required PrinterStore store,
  VoidCallback? onActivated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final l = L.of(ctx);
      final tt = Theme.of(ctx).textTheme;
      // Desplazable: en pantallas bajas o con letra grande no cabe entera.
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l('Quitar la publicidad', 'Remove ads'),
                style: tt.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                l(
                  'También desbloquea logo, nota al pie y tickets propios. '
                      'Imprimir siempre es gratis.',
                  'It also unlocks logo, footer note and custom tickets. '
                      'Printing is always free.',
                ),
                style: tt.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              SectionGroup(
                dividerIndent: 68,
                children: [
                  NavRow(
                    icon: Icons.vpn_key_outlined,
                    title: l('Tengo un código', 'I have a code'),
                    subtitle: l(
                      'Viene con el equipo o lo envía Red Soluciones',
                      'Comes with the hardware or from Red Soluciones',
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await showRedPosActivateDialog(
                        context: context,
                        store: store,
                        onActivated: onActivated,
                      );
                    },
                  ),
                  NavRow(
                    icon: Icons.autorenew_rounded,
                    title: l('Suscripción mensual', 'Monthly subscription'),
                    subtitle: l(
                      'Se paga en Google Play',
                      'Billed by Google Play',
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await openMonthlySubscription(context, store);
                      if (ok) onActivated?.call();
                    },
                  ),
                  NavRow(
                    icon: Icons.all_inclusive_rounded,
                    title: l('Licencia de por vida', 'Lifetime license'),
                    subtitle: l(
                      'Un solo pago, se coordina por correo',
                      'One payment, arranged by email',
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      openLifetimeLicenseMail(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> showRedPosActivateDialog({
  required BuildContext context,
  required PrinterStore store,
  String? address,
  VoidCallback? onActivated,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ActivateCodeDialog(store: store, address: address),
  );
  if (ok == true) {
    onActivated?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L.of(context)(
              'Publicidad desactivada en esta instalación',
              'Ads turned off on this install',
            ),
          ),
        ),
      );
    }
    return true;
  }
  return false;
}

class _ActivateCodeDialog extends StatefulWidget {
  const _ActivateCodeDialog({required this.store, this.address});

  final PrinterStore store;
  final String? address;

  @override
  State<_ActivateCodeDialog> createState() => _ActivateCodeDialogState();
}

class _ActivateCodeDialogState extends State<_ActivateCodeDialog> {
  final _ctrl = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await RedPosLicenseStore.instance.redeem(
      _ctrl.text,
      store: widget.store,
      address: widget.address,
    );
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.message;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AlertDialog(
      scrollable: true,
      icon: const Align(
        child: IconTile(icon: Icons.vpn_key_outlined, size: 52),
      ),
      title: Text(l('Código de activación', 'Activation code')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l(
              'Escribe el código que te dio Red Soluciones. Sin código '
                  'puedes seguir imprimiendo con publicidad.',
              'Enter the code from Red Soluciones. Without a code you can '
                  'keep printing with ads.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            enabled: !_busy,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
            decoration: InputDecoration(
              hintText: 'RP-XXXX-XXXX-XXXX',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
        ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l('Cancelar', 'Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const ButtonSpinner(color: Colors.white)
              : Text(l('Activar', 'Activate')),
        ),
      ],
    );
  }
}
