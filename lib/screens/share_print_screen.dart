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
import '../theme.dart';
import '../widgets/print_status_dialog.dart';
import '../widgets/redpos_ad_banner.dart';
import '../widgets/redpos_paid_gate.dart';
import '../widgets/ui_kit.dart';
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
        builder: (_) => SunatPrintSettingsScreen(store: _sunatStore, printerStore: widget.printerStore),
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
          sunatNote: _sunatFile && _adsFree ? _noteController.text : null,
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
    final tt = Theme.of(context).textTheme;
    final kind = _fileKind(name);

    return Scaffold(
      appBar: AppBar(title: Text(l('Imprimir archivo', 'Print file'))),
      bottomNavigationBar: _loading
          ? null
          : BottomActions(
              children: [
                FilledButton.icon(
                  onPressed: _printing || _selected == null ? null : _print,
                  icon: _printing
                      ? const ButtonSpinner(color: Colors.white)
                      : const Icon(Icons.print_rounded),
                  label: Text(
                    _selected == null
                        ? l('Imprimir', 'Print')
                        : l(
                            'Imprimir en ${_selected!.name}',
                            'Print on ${_selected!.name}',
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageList(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        IconTile(icon: kind.icon, color: kind.color, size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                kind.label(l),
                                style: tt.bodySmall
                                    ?.copyWith(color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_adsFree) ...[
                  const SizedBox(height: 12),
                  RedPosAdBanner(
                    adsFree: _adsFree,
                    store: widget.printerStore,
                    onActivated: _load,
                  ),
                ],
                SectionLabel(l('Imprimir en', 'Print on')),
                if (_printers.isEmpty)
                  InfoNote(
                    tone: InfoTone.warn,
                    icon: Icons.print_disabled_outlined,
                    text: l(
                      'No hay impresoras vinculadas. Abre ${AppBrand.name}, '
                          'vincula una impresora y vuelve a abrir el archivo.',
                      'No printers are paired. Open ${AppBrand.name}, pair a '
                          'printer, then open the file again.',
                    ),
                  )
                else
                  PrinterPicker(
                    printers: _printers,
                    selectedId: _selected?.id,
                    enabled: !_printing,
                    onSelected: (pr) => setState(() => _selected = pr),
                  ),
                if (_sunatFile) ...[
                  SectionLabel(l('Ticket SUNAT', 'SUNAT ticket')),
                  SectionGroup(
                    children: [
                      NavRow(
                        icon: Icons.tune_rounded,
                        title: l(
                          'Configurar ticket SUNAT',
                          'SUNAT ticket settings',
                        ),
                        subtitle: l(
                          'Formato ${_format.label(false).toLowerCase()}. '
                              'El ancho sigue a la impresora.',
                          '${_format.label(true)} format. '
                              'Width follows the printer.',
                        ),
                        onTap: _printing ? null : _openSunatSettings,
                      ),
                      if (_adsFree)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: TextField(
                            controller: _noteController,
                            enabled: !_printing,
                            maxLength: SunatPrintSettings.maxNoteLength,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (value) {
                              _noteDirty = value != _loadedNote;
                            },
                            decoration: InputDecoration(
                              labelText: l('Nota del ticket', 'Ticket note'),
                              helperText: l(
                                'Se imprime al pie. Solo cambia este ticket.',
                                'Printed at the bottom. Only for this ticket.',
                              ),
                              alignLabelWithHint: true,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: RedPosPaidGateBanner(
                            store: widget.printerStore,
                            onUnlocked: _load,
                            compact: true,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _FileKind {
  const _FileKind(this.icon, this.color, this.es, this.en);

  final IconData icon;
  final Color color;
  final String es;
  final String en;

  String label(L l) => l(es, en);
}

_FileKind _fileKind(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.xml') || lower.endsWith('.zip')) {
    return const _FileKind(
      Icons.receipt_long_outlined,
      AppColors.brand,
      'Comprobante SUNAT, se arma como ticket',
      'SUNAT receipt, printed as a ticket',
    );
  }
  if (lower.endsWith('.pdf')) {
    return const _FileKind(
      Icons.picture_as_pdf_outlined,
      Color(0xFFB3261E),
      'Documento PDF',
      'PDF document',
    );
  }
  return const _FileKind(
    Icons.image_outlined,
    AppColors.bluetooth,
    'Imagen',
    'Image',
  );
}

bool _isSunatPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.xml') || lower.endsWith('.zip');
}
