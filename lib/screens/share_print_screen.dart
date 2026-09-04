import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/saved_printer.dart';
import '../services/print_service.dart';
import '../services/printer_permissions.dart';
import '../services/printer_store.dart';
import '../services/transports/printer_transport.dart';
import '../widgets/print_status_dialog.dart';

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
  List<SavedPrinter> _printers = [];
  SavedPrinter? _selected;
  bool _loading = true;
  bool _printing = false;

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

  Future<void> _print() async {
    if (_selected == null) return;
    setState(() => _printing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Siempre releer ajustes guardados (márgenes/papel/corte).
      final all = await widget.printerStore.loadAll();
      final printer = PrinterStore.findByIdOrDefault(all, _selected!.id);
      if (printer == null) {
        throw PrinterTransportException('No hay impresoras vinculadas');
      }
      if (!mounted) return;
      setState(() => _selected = printer);

      if (printer.type == PrinterLinkType.bluetooth) {
        final ok = await PrinterPermissions.ensureBluetooth();
        if (!ok) {
          throw PrinterTransportException(
            'Faltan permisos de Bluetooth. Concedelos en Ajustes de la app.',
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
        ),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Enviado a ${printer.name}')),
      );
      Navigator.of(context).pop(true);
    } on PrinterTransportException catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = p.basename(widget.filePath);

    return Scaffold(
      appBar: AppBar(title: const Text('Imprimir archivo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.picture_as_pdf),
                      title: Text(name),
                      subtitle: Text(widget.filePath, maxLines: 2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Impresora vinculada',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_printers.isEmpty)
                    const Text(
                      'No hay impresoras vinculadas. Abre Boleta Print, '
                      'agrega una impresora y vuelve a compartir el PDF.',
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selected?.id,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Impresora',
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
                                _selected = _printers.firstWhere((p) => p.id == id);
                              });
                            },
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed:
                        _printing || _selected == null ? null : _print,
                    icon: _printing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print),
                    label: const Text('Imprimir'),
                  ),
                ],
              ),
            ),
    );
  }
}
