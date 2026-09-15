import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/app_lang.dart';

/// Fases visibles mientras se imprime.
enum PrintPhase {
  preparing,
  connecting,
  sending,
  printing,
  done,
}

extension PrintPhaseLabel on PrintPhase {
  String title(L l) {
    switch (this) {
      case PrintPhase.preparing:
        return l('Preparando', 'Preparing');
      case PrintPhase.connecting:
        return l('Conectando', 'Connecting');
      case PrintPhase.sending:
        return l('Enviando datos', 'Sending data');
      case PrintPhase.printing:
        return l('Imprimiendo', 'Printing');
      case PrintPhase.done:
        return l('Listo', 'Done');
    }
  }

  String message(L l) {
    switch (this) {
      case PrintPhase.preparing:
        return l('Preparando el ticket...', 'Preparing the ticket...');
      case PrintPhase.connecting:
        return l('Conectando con la impresora...', 'Connecting to the printer...');
      case PrintPhase.sending:
        return l(
          'Enviando datos a la impresora...',
          'Sending data to the printer...',
        );
      case PrintPhase.printing:
        return l('Imprimiendo...', 'Printing...');
      case PrintPhase.done:
        return l('Impresión enviada', 'Print job sent');
    }
  }

  bool get showSpinner => this != PrintPhase.done;
}

/// Ventanita modal de progreso de impresion.
class PrintStatusDialog extends StatelessWidget {
  const PrintStatusDialog({
    super.key,
    required this.phase,
    this.printerName,
  });

  final PrintPhase phase;
  final String? printerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.linear,
              switchOutCurve: Curves.linear,
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: phase.showSpinner
                  ? const RepaintBoundary(
                      key: ValueKey('spin'),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Icon(
                      Icons.check_circle,
                      key: const ValueKey('ok'),
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            phase.title(L.of(context)),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            phase.message(L.of(context)),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (printerName != null && printerName!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              printerName!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Ejecuta un trabajo de impresion mostrando [PrintStatusDialog].
Future<T> runWithPrintStatusDialog<T>({
  required BuildContext context,
  required String printerName,
  required Future<T> Function(void Function(PrintPhase phase) setPhase) job,
}) async {
  final phase = ValueNotifier<PrintPhase>(PrintPhase.preparing);
  final nav = Navigator.of(context, rootNavigator: true);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return PopScope(
        canPop: false,
        child: ValueListenableBuilder<PrintPhase>(
          valueListenable: phase,
          builder: (_, current, __) => PrintStatusDialog(
            phase: current,
            printerName: printerName,
          ),
        ),
      );
    },
  );

  // Dejar que el dialogo pinte antes del trabajo pesado.
  await SchedulerBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 40));

  try {
    final result = await job((p) {
      phase.value = p;
    });
    phase.value = PrintPhase.done;
    // Confirmación visual breve; el transporte ya terminó y no requiere 450 ms.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return result;
  } finally {
    if (nav.mounted && nav.canPop()) {
      nav.pop();
    }
    phase.dispose();
  }
}
