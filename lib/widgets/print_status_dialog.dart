import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Fases visibles mientras se imprime.
enum PrintPhase {
  preparing,
  connecting,
  sending,
  printing,
  done,
}

extension PrintPhaseLabel on PrintPhase {
  String get title {
    switch (this) {
      case PrintPhase.preparing:
        return 'Preparando';
      case PrintPhase.connecting:
        return 'Conectando';
      case PrintPhase.sending:
        return 'Enviando datos';
      case PrintPhase.printing:
        return 'Imprimiendo';
      case PrintPhase.done:
        return 'Listo';
    }
  }

  String get message {
    switch (this) {
      case PrintPhase.preparing:
        return 'Preparando el ticket...';
      case PrintPhase.connecting:
        return 'Conectando con la impresora...';
      case PrintPhase.sending:
        return 'Enviando datos a la impresora...';
      case PrintPhase.printing:
        return 'Imprimiendo...';
      case PrintPhase.done:
        return 'Impresion enviada';
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
              child: phase.showSpinner
                  ? const CircularProgressIndicator(
                      key: ValueKey('spin'),
                      strokeWidth: 3,
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              phase.title,
              key: ValueKey(phase.title),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              phase.message,
              key: ValueKey(phase.message),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
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
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return result;
  } finally {
    if (nav.mounted && nav.canPop()) {
      nav.pop();
    }
    phase.dispose();
  }
}
