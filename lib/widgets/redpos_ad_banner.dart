import 'package:flutter/material.dart';

import '../screens/help_screen.dart';
import '../services/printer_store.dart';
import '../services/redpos/redpos_license.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App de uso gratuito. Sin código RedPOS o suscripción '
              'verás este aviso y un pie en el papel.',
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
                  child: const Text('Tengo un código'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HelpScreen(),
                      ),
                    );
                  },
                  child: const Text('Quiero suscripción'),
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
        const SnackBar(
          content: Text('Publicidad desactivada en esta instalación'),
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
    return AlertDialog(
      title: const Text('Código de activación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'El código lo entrega RedPOS con el equipo o al pagar. '
            'Sin código puedes seguir imprimiendo con publicidad.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: 'Código',
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
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Activar'),
        ),
      ],
    );
  }
}
