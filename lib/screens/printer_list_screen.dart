import 'package:flutter/material.dart';

import '../models/saved_printer.dart';
import '../services/print_service.dart';
import '../services/printer_permissions.dart';
import '../services/printer_store.dart';
import '../services/transports/printer_transport.dart';
import '../widgets/print_status_dialog.dart';
import 'print_history_screen.dart';
import 'printer_form_screen.dart';

class PrinterListScreen extends StatefulWidget {
  const PrinterListScreen({
    super.key,
    required this.store,
    required this.printService,
  });

  final PrinterStore store;
  final PrintService printService;

  @override
  State<PrinterListScreen> createState() => _PrinterListScreenState();
}

class _PrinterListScreenState extends State<PrinterListScreen> {
  List<SavedPrinter> _printers = [];
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskOverlay());
  }

  Future<void> _maybeAskOverlay() async {
    if (!mounted) return;
    final ok = await PrinterPermissions.hasSystemOverlay();
    if (ok || !mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Impresión del sistema'),
        content: const Text(
          'Para imprimir desde el diálogo Imprimir sin salir de la otra app, '
          'hay que permitir «Mostrar sobre otras apps». Verás un recuadro '
          'flotante de progreso encima.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Después'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Permitir'),
          ),
        ],
      ),
    );
    if (go == true) {
      await PrinterPermissions.ensureSystemOverlay();
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final all = await widget.store.loadAll();
    if (!mounted) return;
    setState(() {
      _printers = all;
      _loading = false;
    });
  }

  Future<void> _openForm({SavedPrinter? existing}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrinterFormScreen(
          store: widget.store,
          printService: widget.printService,
          existing: existing,
        ),
      ),
    );
    if (result == true) await _reload();
  }

  Future<void> _testPrint(SavedPrinter printer) async {
    setState(() => _busyId = printer.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fresh = PrinterStore.findByIdOrDefault(
        await widget.store.loadAll(),
        printer.id,
      );
      if (fresh == null) {
        throw PrinterTransportException('Impresora no encontrada');
      }
      if (!mounted) return;
      await runWithPrintStatusDialog(
        context: context,
        printerName: fresh.name,
        job: (setPhase) => widget.printService.printTestPage(
          fresh,
          onPhase: setPhase,
        ),
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Prueba enviada a ${printer.name}')),
      );
    } on PrinterTransportException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _unlink(SavedPrinter printer) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular impresora'),
        content: Text(
          '¿Quitar "${printer.name}" de Boleta Print?\n'
          '(No borra el emparejado Bluetooth del sistema Android.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.store.delete(printer.id);
    await _reload();
  }

  void _openHistory({SavedPrinter? printer}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrintHistoryScreen(
          history: widget.printService.history,
          printer: printer,
        ),
      ),
    );
  }

  void _showPrinterActions(SavedPrinter printer) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  printer.type == PrinterLinkType.bluetooth
                      ? Icons.bluetooth_connected
                      : Icons.wifi,
                ),
                title: Text(printer.name),
                subtitle: Text(
                  '${printer.type.label} · ${printer.paper.label}\n'
                  '${printer.connectionSummary}',
                ),
                isThreeLine: true,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.print),
                title: const Text('Probar impresion'),
                onTap: () {
                  Navigator.pop(ctx);
                  _testPrint(printer);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Ver historial'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openHistory(printer: printer);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Configurar'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openForm(existing: printer);
                },
              ),
              if (!printer.isDefault)
                ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: const Text('Marcar predeterminada'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await widget.store.setDefault(printer.id);
                    await _reload();
                  },
                ),
              ListTile(
                leading: Icon(Icons.link_off, color: Theme.of(ctx).colorScheme.error),
                title: Text(
                  'Desvincular',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _unlink(printer);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boleta Print'),
        actions: [
          IconButton(
            tooltip: 'Historial',
            onPressed: () => _openHistory(),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Vincular'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _printers.isEmpty
              ? _EmptyState(onAdd: () => _openForm())
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: _printers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = _printers[index];
                    final busy = _busyId == p.id;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            p.type == PrinterLinkType.bluetooth
                                ? Icons.bluetooth
                                : Icons.wifi,
                          ),
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                          p.isDefault
                              ? 'Predeterminada · ${p.type.label} · ${p.paper.label}'
                              : '${p.type.label} · ${p.paper.label}',
                        ),
                        trailing: busy
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                tooltip: 'Opciones',
                                icon: const Icon(Icons.more_vert),
                                onPressed: () => _showPrinterActions(p),
                              ),
                        onTap: () => _showPrinterActions(p),
                      ),
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.print_disabled,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin impresoras vinculadas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Vincula una impresora termica (Bluetooth o WiFi). '
              'El historial de trabajos se ve en el icono de reloj o en las opciones de cada impresora.\n\n'
              'Tambien puedes compartir un PDF hacia esta app desde otras apps.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_link),
              label: const Text('Vincular impresora'),
            ),
          ],
        ),
      ),
    );
  }
}
