import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../models/paper_width.dart';
import '../models/saved_printer.dart';
import '../services/custom_ticket/custom_ticket.dart';
import '../services/print_service.dart';
import '../services/printer_permissions.dart';
import '../services/printer_store.dart';
import '../services/transports/printer_transport.dart';
import '../theme.dart';
import '../widgets/print_status_dialog.dart';
import '../widgets/ui_kit.dart';

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
              'Faltan permisos de Bluetooth. Concédelos en Ajustes de la app.',
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

    final showLogo =
        widget.template.showLogo && widget.template.logoBytes != null;
    final paperWidth =
        (_selected?.paper ?? PaperWidth.mm58) == PaperWidth.mm80 ? 360.0 : 280.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.name),
      ),
      bottomNavigationBar: _loading
          ? null
          : BottomActions(
              children: [
                FilledButton.icon(
                  onPressed: _printing || _selected == null ? null : _print,
                  icon: _printing
                      ? const ButtonSpinner(color: Colors.white)
                      : const Icon(Icons.print_rounded),
                  label: Text(l('Imprimir', 'Print')),
                ),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageList(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: paperWidth),
                    child: PhysicalShape(
                      clipper: const TornPaperClipper(tooth: 9, depth: 6),
                      color: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.4),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 18, 14, 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showLogo) ...[
                              SizedBox(
                                height: 64,
                                child: Image.memory(
                                  widget.template.logoBytes!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topLeft,
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l(
                    'Ancho de $paperLabel, según la impresora elegida.',
                    '$paperLabel wide, based on the chosen printer.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.inkSoft),
                ),
                SectionLabel(l('Imprimir en', 'Print on')),
                if (_printers.isEmpty)
                  InfoNote(
                    tone: InfoTone.warn,
                    icon: Icons.print_disabled_outlined,
                    text: l(
                      'No hay impresoras vinculadas. Vincula una en el inicio.',
                      'No printers are paired. Pair one on the home screen.',
                    ),
                  )
                else
                  PrinterPicker(
                    printers: _printers,
                    selectedId: _selected?.id,
                    enabled: !_printing,
                    onSelected: (pr) => setState(() => _selected = pr),
                  ),
              ],
            ),
    );
  }
}