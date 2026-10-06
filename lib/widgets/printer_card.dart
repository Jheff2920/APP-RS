import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../models/saved_printer.dart';

/// Tarjeta de impresora con botón de prueba directo y menú de opciones.
/// El botón "Imprimir prueba" queda visible siempre — acción principal a un toque.
class PrinterCard extends StatelessWidget {
  const PrinterCard({
    super.key,
    required this.printer,
    required this.busy,
    required this.onTestPrint,
    required this.onOptions,
  });

  final SavedPrinter printer;
  final bool busy;
  final VoidCallback onTestPrint;
  final VoidCallback onOptions;

  static IconData _typeIcon(PrinterLinkType t) => switch (t) {
        PrinterLinkType.bluetooth => Icons.bluetooth,
        PrinterLinkType.usb => Icons.usb,
        PrinterLinkType.network => Icons.wifi,
      };

  static Color _typeColor(PrinterLinkType t, ColorScheme cs) => switch (t) {
        PrinterLinkType.bluetooth => const Color(0xFF1565C0),
        PrinterLinkType.usb => const Color(0xFFE65100),
        PrinterLinkType.network => cs.primary,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = L.of(context);
    final iconColor = _typeColor(printer.type, cs);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onOptions,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              // Ícono de tipo de conexión con fondo tintado
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_typeIcon(printer.type), color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              // Nombre y detalles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            printer.name,
                            style: tt.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (printer.isDefault) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star_rounded,
                              size: 16, color: cs.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${printer.type.label} · ${printer.paper.label} · ${printer.connectionSummary}',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Botón de prueba directo
              if (busy)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: RepaintBoundary(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else
                _TestButton(
                  onTap: onTestPrint,
                  label: l('Probar', 'Test'),
                ),
              // Menú de opciones
              if (!busy)
                IconButton(
                  tooltip: l('Opciones', 'Options'),
                  icon: const Icon(Icons.more_vert),
                  onPressed: onOptions,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({required this.onTap, required this.label});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(6),
          color: cs.primaryContainer.withValues(alpha: 0.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.print_outlined, size: 14, color: cs.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
