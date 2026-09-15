import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../screens/redpos_subscribe_screen.dart';
import '../services/printer_store.dart';
import '../services/redpos/redpos_config.dart';
import '../services/redpos/redpos_links.dart';

Future<bool> openMonthlySubscription(
  BuildContext context,
  PrinterStore store,
) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => RedPosSubscribeScreen(store: store),
    ),
  );
  if (ok == true && context.mounted) {
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
  return ok == true;
}

Future<void> openLifetimeLicenseMail(BuildContext context) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final l = L.of(ctx);
      return AlertDialog(
        title: Text(l('Licencia de por vida', 'Lifetime license')),
        content: Text(
          l(
            'Escríbenos y te respondemos con un código RedPOS para pegar en '
            '«Tengo un código». El precio se acuerda por correo; no se cobra '
            'dentro de Play.',
            'Write us and we will reply with a RedPOS code to paste under '
            '“I have a code”. The price is agreed by email; it is not charged '
            'in Play.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l('Cancelar', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l('Escribir correo', 'Write email')),
          ),
        ],
      );
    },
  );
  if (go != true || !context.mounted) return;
  await openRedPosLink(context, RedPosConfig.lifetimeMailtoUri);
}
