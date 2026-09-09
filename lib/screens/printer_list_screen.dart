import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/saved_printer.dart';
import '../platform_caps.dart';
import '../services/bluetooth_bond_channel.dart';
import '../services/print_service.dart';
import '../services/printer_permissions.dart';
import '../services/printer_store.dart';
import '../services/transports/printer_transport.dart';
import '../widgets/boleta_page.dart';
import '../widgets/print_status_dialog.dart';
import 'print_history_screen.dart';
import 'printer_form_screen.dart';
import 'share_print_screen.dart';

const _expandedBreakpoint = 840.0;

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
  final _detailNavKey = GlobalKey<NavigatorState>();
  List<SavedPrinter> _printers = [];
  bool _loading = true;
  String? _busyId;
  bool _detailIsAddForm = false;
  bool _openingForm = false;

  bool get _expanded => MediaQuery.sizeOf(context).width >= _expandedBreakpoint;

  @override
  void initState() {
    super.initState();
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskOverlay());
  }

  Future<void> _maybeAskOverlay() async {
    if (!PlatformCaps.supportsSystemPrint) return;
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
    if (_openingForm) return;
    if (existing == null && _detailIsAddForm) return;
    _openingForm = true;
    final form = PrinterFormScreen(
      store: widget.store,
      printService: widget.printService,
      existing: existing,
    );
    try {
      if (_expanded) {
        setState(() => _detailIsAddForm = existing == null);
        final nav = _detailNavKey.currentState;
        if (nav == null) return;
        final result = await nav.push<bool>(
          MaterialPageRoute(builder: (_) => form),
        );
        if (mounted) setState(() => _detailIsAddForm = false);
        if (result == true) await _reload();
        return;
      }
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => form),
      );
      if (result == true) await _reload();
    } finally {
      _openingForm = false;
    }
  }

  Future<void> _openSharedFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'xml', 'zip', 'png', 'jpg', 'jpeg'],
      );
      final path = picked?.files.single.path;
      if (path == null || path.isEmpty || !mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SharePrintScreen(
            filePath: path,
            printerStore: widget.store,
            printService: widget.printService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el archivo: $e')),
      );
    }
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
    final bluetoothNote = printer.type != PrinterLinkType.bluetooth
        ? ''
        : PlatformCaps.isAndroid
            ? '\nTambién se olvidará del Bluetooth del teléfono.'
            : '\nEn iPhone/iPad hay que olvidarla en Ajustes > Bluetooth.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular impresora'),
        content: Text(
          '¿Quitar "${printer.name}" de Boleta Print?$bluetoothNote',
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
    String? bluetoothError;
    if (printer.type == PrinterLinkType.bluetooth) {
      try {
        if (PlatformCaps.isAndroid) {
          final permitted = await PrinterPermissions.ensureBluetooth();
          if (!permitted) {
            bluetoothError =
                'Se quitó de la app, pero faltan permisos para olvidarla del Bluetooth.';
          } else {
            await BluetoothBondChannel.forget(printer.address);
          }
        } else {
          await BluetoothBondChannel.forget(printer.address);
        }
      } catch (e) {
        bluetoothError =
            'Se quitó de la app, pero no se pudo olvidar del Bluetooth: $e';
      }
    }
    await widget.store.delete(printer.id);
    if (_expanded) {
      _detailNavKey.currentState?.popUntil((route) => route.isFirst);
      if (mounted) setState(() => _detailIsAddForm = false);
    }
    await _reload();
    if (!mounted || bluetoothError == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(bluetoothError)),
    );
  }

  void _openHistory({SavedPrinter? printer}) {
    final screen = PrintHistoryScreen(
      history: widget.printService.history,
      printer: printer,
    );
    if (_expanded) {
      _detailNavKey.currentState?.push(
        MaterialPageRoute(builder: (_) => screen),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
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
                      : printer.type == PrinterLinkType.usb
                          ? Icons.usb
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
                title: const Text('Probar impresión'),
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

  Widget _listBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_printers.isEmpty) {
      return _EmptyState(
        showUsb: PlatformCaps.supportsUsb,
        onAdd: () => _openForm(),
        onOpenFile: _openSharedFile,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      scrollCacheExtent: const ScrollCacheExtent.pixels(280),
      itemCount: _printers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = _printers[index];
        final busy = _busyId == p.id;
        return Card(
          child: RepaintBoundary(
            child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                p.type == PrinterLinkType.bluetooth
                    ? Icons.bluetooth
                    : p.type == PrinterLinkType.usb
                        ? Icons.usb
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
          ),
        );
      },
    );
  }

  Widget _detailPane() {
    return Navigator(
      key: _detailNavKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
          builder: (context) => const _DetailPlaceholder(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded;
    final hideFab = expanded && _detailIsAddForm;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boleta Print'),
        actions: [
          IconButton(
            tooltip: 'Abrir archivo',
            onPressed: _openSharedFile,
            icon: const Icon(Icons.folder_open),
          ),
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
      floatingActionButton: hideFab
          ? null
          : FloatingActionButton.extended(
              onPressed: _openingForm ? null : () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Vincular'),
            ),
      body: expanded
          ? Row(
              children: [
                Expanded(flex: 2, child: _listBody()),
                const VerticalDivider(width: 1),
                Expanded(flex: 3, child: _detailPane()),
              ],
            )
          : _listBody(),
    );
  }
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Icon(
          Icons.print,
          size: 48,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onAdd,
    required this.onOpenFile,
    required this.showUsb,
  });

  final VoidCallback onAdd;
  final VoidCallback onOpenFile;
  final bool showUsb;

  @override
  Widget build(BuildContext context) {
    final types = showUsb
        ? '${PrinterLinkType.bluetooth.label}, ${PrinterLinkType.network.label} o ${PrinterLinkType.usb.label}'
        : '${PrinterLinkType.bluetooth.label} o ${PrinterLinkType.network.label}';
    return BoletaPage(
      child: Center(
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
              Text(
                'Vincula una impresora térmica ($types). '
                'El historial de trabajos se ve en el icono de reloj o en las opciones de cada impresora.\n\n'
                '${showUsb ? 'También puedes compartir un PDF hacia esta app desde otras apps.' : 'En iPhone/iPad imprime por WiFi (TCP 9100). Abre un PDF, XML o ZIP SUNAT con el botón de carpeta.'}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_link),
                label: const Text('Vincular impresora'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onOpenFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Abrir archivo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
