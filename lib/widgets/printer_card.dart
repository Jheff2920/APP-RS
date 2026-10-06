import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../models/saved_printer.dart';

/// Tarjeta de impresora con boton de prueba directo y menu de opciones.
/// El boton "Probar" queda visible siempre — accion principal a un toque.
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
        PrinterLinkType.bluetooth => Icons.bluetooth_rounded,
        PrinterLinkType.usb => Icons.usb_rounded,
        PrinterLinkType.network => Icons.wifi_rounded,
      };

  // Colores por tipo de conexion — distintivos, no identicos
  static Color _typeColor(PrinterLinkType t) => switch (t) {
        PrinterLinkType.bluetooth => const Color(0xFF1565C0),
        PrinterLinkType.usb => const Color(0xFFBF360C),
        PrinterLinkType.network => const Color(0xFF2B0A53),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = L.of(context);
    final iconColor = _typeColor(printer.type);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOptions,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              // Icono de tipo con fondo tintado
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon(printer.type),
                    color: iconColor, size: 24),
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
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (printer.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l('Principal', 'Default'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${printer.type.label} · ${printer.paper.label}',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      printer.connectionSummary,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Boton de prueba o spinner
              if (busy)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: RepaintBoundary(
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: cs.primary),
                    ),
                  ),
                )
              else
                _TestButton(
                  onTap: onTestPrint,
                  label: l('Probar', 'Test'),
                ),
              // Menu de opciones
              if (!busy)
                IconButton(
                  tooltip: l('Opciones', 'Options'),
                  icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.print_rounded, size: 14, color: cs.primary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
