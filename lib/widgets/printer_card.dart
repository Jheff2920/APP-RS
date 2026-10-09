import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../models/saved_printer.dart';
import 'ui_kit.dart';

/// Fila de impresora: tocar abre opciones; "Probar" queda a un toque.
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _card(
        context,
        compact: constraints.maxWidth < 400,
      ),
    );
  }

  Widget _card(BuildContext context, {required bool compact}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = L.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOptions,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(
            children: [
              IconTile(
                icon: printerTypeIcon(printer.type),
                color: printerTypeColor(printer.type),
                size: compact ? 42 : 46,
              ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      printer.name,
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Wrap: con letra grande o poco ancho, la insignia baja de línea.
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (printer.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              l('Principal', 'Default'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        Text(
                          '${printer.type.label}, ${printer.paper.label}',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Text(
                      printer.connectionSummary,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: RepaintBoundary(child: ButtonSpinner()),
                )
              else if (compact)
                IconButton.filledTonal(
                  tooltip: l('Probar impresión', 'Test print'),
                  onPressed: onTestPrint,
                  icon: const Icon(Icons.print_outlined),
                )
              else
                _TestButton(onTap: onTestPrint, label: l('Probar', 'Test')),
              IconButton(
                tooltip: l('Opciones', 'Options'),
                icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
                onPressed: busy ? null : onOptions,
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
      color: cs.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.print_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
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
