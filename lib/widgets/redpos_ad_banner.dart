import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../services/printer_store.dart';
import '../services/redpos/redpos_license.dart';
import '../widgets/redpos_unlock_actions.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l(
                'App de uso gratuito. Sin código RedPOS, suscripción o licencia '
                'de por vida verás este aviso y un pie en el papel.',
                'Free to use. Without a RedPOS code, subscription, or lifetime '
                'license you will see this notice and a footer on the ticket.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => showRedPosActivateDialog(
                    context: context,
                    store: store,
                    onActivated: onActivated,
                  ),
                  child: Text(l('Tengo un código', 'I have a code')),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await openMonthlySubscription(context, store);
                    if (ok) onActivated?.call();
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
      title: Text(l('Código de activación', 'Activation code')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l(
              'El código lo entrega RedPOS con el equipo o al pagar una licencia '
              'de por vida. Sin código puedes seguir imprimiendo con publicidad.',
              'RedPOS provides the code with the hardware or after a lifetime '
              'license. Without a code you can keep printing with ads.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: l('Código', 'Code'),
              hintText: 'RP-XXXX-XXXX-XXXX',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l('Cancelar', 'Cancel')),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l('Activar', 'Activate')),
        ),
      ],
    );
  }
}
