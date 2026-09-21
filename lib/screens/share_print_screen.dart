import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../brand.dart';
import '../l10n/app_lang.dart';
import '../models/saved_printer.dart';
import '../services/print_service.dart';
import '../services/printer_permissions.dart';
import '../services/printer_store.dart';
import '../services/redpos/redpos_license.dart';
import '../services/sunat/sunat_print_settings.dart';
import '../services/transports/printer_transport.dart';
import '../widgets/boleta_page.dart';
import '../widgets/print_status_dialog.dart';
import '../widgets/redpos_ad_banner.dart';
import 'sunat_print_settings_screen.dart';

class SharePrintScreen extends StatefulWidget {
  const SharePrintScreen({
    super.key,
    required this.filePath,
    required this.printerStore,
    required this.printService,
  });

  final String filePath;
  final PrinterStore printerStore;
  final PrintService printService;

  @override
  State<SharePrintScreen> createState() => _SharePrintScreenState();
}

class _SharePrintScreenState extends State<SharePrintScreen> {
  final _noteController = TextEditingController();
  final _sunatStore = SunatPrintStore();
  List<SavedPrinter> _printers = [];
  SavedPrinter? _selected;
  bool _loading = true;
  bool _printing = false;
  bool _adsFree = false;
  bool _noteDirty = false;
  String _loadedNote = '';
  SunatTicketFormat _format = SunatTicketFormat.claro;

  bool get _sunatFile => _isSunatPath(widget.filePath);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await widget.printerStore.loadAll();
    final adsFree =
        await RedPosLicenseStore.instance.isAdsFree(reloadDisk: false);
    final sunat = _sunatFile ? await _sunatStore.load() : null;
    if (!mounted) return;
    if (sunat != null && !_noteDirty) {
      _noteController.text = sunat.footerNote;
      _loadedNote = sunat.footerNote;
      _format = sunat.format;
    } else if (sunat != null) {
      _format = sunat.format;
    }
    setState(() {
      _printers = all;
      _selected = PrinterStore.findByIdOrDefault(all, '');
      _adsFree = adsFree;
      _loading = false;
    });
  }

  Future<void> _openSunatSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SunatPrintSettingsScreen(store: _sunatStore),
      ),
    );
    if (!mounted) return;
    final settings = await _sunatStore.load();
    if (!mounted) return;
    if (!_noteDirty || _noteController.text == _loadedNote) {
      _noteController.text = settings.footerNote;
      _noteDirty = false;
    }
    setState(() {
      _loadedNote = settings.footerNote;
      _format = settings.format;
    });
  }

  Future<void> _print() async {
    if (_selected == null) return;
    setState(() => _printing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Siempre releer ajustes guardados (márgenes/papel/corte).
      final all = await widget.printerStore.loadAll();
      final printer = PrinterStore.findByIdOrDefault(all, _selected!.id);
      if (printer == null) {
        throw PrinterTransportException(
          tr('No hay impresoras vinculadas', 'No printers are paired'),
        );
      }
      if (!mounted) return;
      setState(() => _selected = printer);

      if (printer.type == PrinterLinkType.bluetooth) {
        final ok = await PrinterPermissions.ensureBluetooth();
        if (!ok) {
          throw PrinterTransportException(
            tr(
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
        job: (setPhase) => widget.printService.printSharedFile(
          printer: printer,
          filePath: widget.filePath,
          onPhase: setPhase,
          requestPermissions: false,
          sunatNote: _sunatFile ? _noteController.text : null,
        ),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('Enviado a ${printer.name}', 'Sent to ${printer.name}'),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on PrinterTransportException catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              tr(
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
    final name = p.basename(widget.filePath);
    final l = L.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l('Imprimir archivo', 'Print file'))),
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
                  RedPosAdBanner(
                    adsFree: _adsFree,
                    store: widget.printerStore,
                    onActivated: _load,
                  ),
                  if (!_adsFree) const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        _isXmlLike(name)
                            ? Icons.description
                            : Icons.picture_as_pdf,
                      ),
                      title: Text(name),
                      subtitle: Text(
                        _isXmlLike(name)
                            ? l(
                                'XML SUNAT → ticket ${(_selected?.paper.label ?? '')}',
                                'SUNAT XML → ${(_selected?.paper.label ?? '')} ticket',
                              )
                            : widget.filePath,
                        maxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l('Impresora vinculada', 'Paired printer'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_printers.isEmpty)
                    Text(
                      l(
                        'No hay impresoras vinculadas. Abre ${AppBrand.name}, '
                        'agrega una impresora y vuelve a abrir el archivo.',
                        'No printers are paired. Open ${AppBrand.name}, add a '
                        'printer, then open the file again.',
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
                  if (_sunatFile) ...[
                    const SizedBox(height: 16),
                    Text(
                      l('Ticket SUNAT', 'SUNAT ticket'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l(
                        'Formato: ${_format.label(false)}. '
                        'El ancho es el de la impresora (58 u 80 mm).',
                        'Format: ${_format.label(true)}. '
                        'Width follows the printer (58 or 80 mm).',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _printing ? null : _openSunatSettings,
                        icon: const Icon(Icons.tune),
                        label: Text(
                          l(
                            'Configurar ticket SUNAT',
                            'SUNAT ticket settings',
                          ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: _noteController,
                      enabled: !_printing,
                      maxLength: SunatPrintSettings.maxNoteLength,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (value) {
                        _noteDirty = value != _loadedNote;
                      },
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: l('Nota del ticket', 'Ticket note'),
                        helperText: l(
                          'Se imprime al pie. El cambio vale solo para este trabajo.',
                          'Printed at the bottom. The change applies only to this job.',
                        ),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  bool _isXmlLike(String name) => _isSunatPath(name);
}

bool _isSunatPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.xml') || lower.endsWith('.zip');
}
