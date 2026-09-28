import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../models/paper_width.dart';
import '../models/saved_printer.dart';
import '../services/custom_ticket/custom_ticket.dart';
import '../services/print_service.dart';
import '../services/printer_permissions.dart';
import '../services/printer_store.dart';
import '../services/transports/printer_transport.dart';
import '../widgets/boleta_page.dart';
import '../widgets/print_status_dialog.dart';

/// Vista previa en pantalla e impresión del ticket propio.
class CustomTicketPreviewScreen extends StatefulWidget {
  const CustomTicketPreviewScreen({
    super.key,
    required this.template,
    required this.printerStore,
    required this.printService,
  });

  final CustomTicketTemplate template;
  final PrinterStore printerStore;
  final PrintService printService;

  @override
  State<CustomTicketPreviewScreen> createState() =>
      _CustomTicketPreviewScreenState();
}

class _CustomTicketPreviewScreenState extends State<CustomTicketPreviewScreen> {
  List<SavedPrinter> _printers = [];
  SavedPrinter? _selected;
  var _loading = true;
  var _printing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.printerStore.loadAll();
    if (!mounted) return;
    setState(() {
      _printers = all;
      _selected = PrinterStore.findByIdOrDefault(all, '');
      _loading = false;
    });
  }

  int get _previewCols {
    final paper = _selected?.paper ?? PaperWidth.mm58;
    return paper.charsPerLine;
  }

  Future<void> _print() async {
    if (_selected == null) return;
    setState(() => _printing = true);
    final messenger = ScaffoldMessenger.of(context);
    final l = L.of(context);
    try {
      final all = await widget.printerStore.loadAll();
      final printer = PrinterStore.findByIdOrDefault(all, _selected!.id);
      if (printer == null) {
        throw PrinterTransportException(
          l('No hay impresoras vinculadas', 'No printers are paired'),
        );
      }
      if (!mounted) return;
      setState(() => _selected = printer);

      if (printer.type == PrinterLinkType.bluetooth) {
        final ok = await PrinterPermissions.ensureBluetooth();
        if (!ok) {
          throw PrinterTransportException(
            l(
              'Faltan permisos de Bluetooth. Concedelos en Ajustes de la app.',
              'Bluetooth permission is missing. Allow it in app Settings.',
            ),
          );
        }
      }
      if (!mounted) return;
      await runWithPrintStatusDialog(
        context: context,
        printerName: printer.name,
        job: (setPhase) => widget.printService.printCustomTicket(
          printer: printer,
          template: widget.template,
          onPhase: setPhase,
          requestPermissions: false,
        ),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l('Enviado a ${printer.name}', 'Sent to ${printer.name}')),
        ),
      );
    } on PrinterTransportException catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l(
                'No se pudo imprimir. Enciende la impresora e inténtalo de nuevo.',
                'Could not print. Turn the printer on and try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final lines = widget.template.previewLines(cols: _previewCols);
    final paperLabel = _selected?.paper.label ?? '58 mm';

    return Scaffold(
      appBar: AppBar(
        title: Text(l('Vista previa', 'Preview')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : BoletaPage(
              bottomBar: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _printing || _selected == null ? null : _print,
                  icon: _printing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print),
                  label: Text(l('Imprimir', 'Print')),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.template.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l(
                      'Ancho según la impresora ($paperLabel).',
                      'Width follows the printer ($paperLabel).',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l('Impresora vinculada', 'Paired printer'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_printers.isEmpty)
                    Text(
                      l(
                        'No hay impresoras vinculadas. Agrega una en la pantalla principal.',
                        'No printers are paired. Add one on the home screen.',
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selected?.id,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: l('Impresora', 'Printer'),
                      ),
                      items: _printers
                          .map(
                            (pr) => DropdownMenuItem(
                              value: pr.id,
                              child: Text('${pr.name} (${pr.paper.label})'),
                            ),
                          )
                          .toList(),
                      onChanged: _printing
                          ? null
                          : (id) {
                              setState(() {
                                _selected =
                                    _printers.firstWhere((p) => p.id == id);
                              });
                            },
                    ),
                  const SizedBox(height: 16),
                  Text(
                    l('Vista previa', 'Preview'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                      child: SelectableText(
                        lines.isEmpty
                            ? l('(vacío)', '(empty)')
                            : lines.join('\n'),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          height: 1.35,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  if (widget.template.showLogo &&
                      widget.template.logoBytes != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      l(
                        'El logo se imprime como imagen; debajo van nombre, RUC y dirección.',
                        'The logo prints as an image; name, RUC and address follow below.',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Image.memory(
                      widget.template.logoBytes!,
                      height: 72,
                      fit: BoxFit.contain,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}