import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../brand.dart';
import '../l10n/app_lang.dart';
import '../models/saved_printer.dart';
import '../platform_caps.dart';
import '../services/bluetooth_bond_channel.dart';
import '../services/print_service.dart';
import '../services/printer_permissions.dart';
import '../services/printer_store.dart';
import '../services/redpos/redpos_license.dart';
import '../services/transports/printer_transport.dart';
import '../widgets/boleta_page.dart';
import '../widgets/print_status_dialog.dart';
import '../widgets/redpos_ad_banner.dart';
import 'help_screen.dart';
import 'print_history_screen.dart';
import 'printer_form_screen.dart';
import 'share_print_screen.dart';
import 'legal_screen.dart';

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
  bool _adsFree = false;

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
      builder: (ctx) {
        final l = L.of(ctx);
        return AlertDialog(
          title: Text(l('Impresión del sistema', 'System printing')),
          content: Text(
            l(
              'Para imprimir desde el diálogo Imprimir sin salir de la otra app, '
              'hay que permitir «Mostrar sobre otras apps». Verás un recuadro '
              'flotante de progreso encima.',
              'To print from the system Print dialog without leaving the other app, '
              'allow “Display over other apps”. You will see a floating progress box.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l('Después', 'Later')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l('Permitir', 'Allow')),
            ),
          ],
        );
      },
    );
    if (go == true) {
      await PrinterPermissions.ensureSystemOverlay();
    }
  }

  Future<void> _reload() async {
    if (!mounted) return;
    if (_printers.isEmpty) {
      setState(() => _loading = true);
    }
    final all = await widget.store.loadAll();
    final adsFree =
        await RedPosLicenseStore.instance.isAdsFree(reloadDisk: false);
    if (!mounted) return;
    setState(() {
      _printers = all;
      _adsFree = adsFree;
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
      onStoreChanged: () {
        if (mounted) unawaited(_reload());
      },
    );
    try {
      if (_expanded) {
        setState(() => _detailIsAddForm = existing == null);
        final nav = _detailNavKey.currentState;
        if (nav == null) {
          if (mounted) setState(() => _detailIsAddForm = false);
          return;
        }
        await nav.push<bool>(
          MaterialPageRoute(builder: (_) => form),
        );
        if (mounted) {
          setState(() => _detailIsAddForm = false);
          await _reload();
        }
        return;
      }
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => form),
      );
      if (mounted && result == true) await _reload();
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
        SnackBar(
          content: Text(
            L.of(context)('No se pudo abrir el archivo: $e', 'Could not open the file: $e'),
          ),
        ),
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
        throw PrinterTransportException(
          tr('Impresora no encontrada', 'Printer not found'),
        );
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
        SnackBar(
          content: Text(
            L.of(context)(
              'Prueba enviada a ${printer.name}',
              'Test page sent to ${printer.name}',
            ),
          ),
        ),
      );
    } on PrinterTransportException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            L.of(context)(
              'No se pudo completar la prueba. Enciende la impresora e inténtalo de nuevo.',
              'Could not finish the test. Turn the printer on and try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _unlink(SavedPrinter printer) async {
    final l = L.of(context);
    final bluetoothNote = printer.type != PrinterLinkType.bluetooth
        ? ''
        : PlatformCaps.isAndroid
            ? l(
                '\nTambién se olvidará del Bluetooth del teléfono.',
                '\nIt will also be forgotten from the phone Bluetooth.',
              )
            : l(
                '\nEn iPhone/iPad hay que olvidarla en Ajustes > Bluetooth.',
                '\nOn iPhone/iPad, forget it in Settings > Bluetooth.',
              );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l('Desvincular impresora', 'Unlink printer')),
        content: Text(
          l(
            '¿Quitar "${printer.name}" de ${AppBrand.name}?$bluetoothNote',
            'Remove "${printer.name}" from ${AppBrand.name}?$bluetoothNote',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l('Cancelar', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l('Desvincular', 'Unlink')),
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
            bluetoothError = tr(
              'Se quitó de la app, pero faltan permisos para olvidarla del Bluetooth.',
              'Removed from the app, but Bluetooth permission is needed to forget it.',
            );
          } else {
            await BluetoothBondChannel.forget(printer.address);
          }
        } else {
          await BluetoothBondChannel.forget(printer.address);
        }
      } catch (e) {
        bluetoothError = tr(
          'Se quitó de la app, pero no se pudo olvidar del Bluetooth: $e',
          'Removed from the app, but it could not be forgotten from Bluetooth: $e',
        );
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
                title: Text(L.of(ctx)('Probar impresión', 'Test print')),
                onTap: () {
                  Navigator.pop(ctx);
                  _testPrint(printer);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(L.of(ctx)('Ver historial', 'View history')),
                onTap: () {
                  Navigator.pop(ctx);
                  _openHistory(printer: printer);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(L.of(ctx)('Configurar', 'Settings')),
                onTap: () {
                  Navigator.pop(ctx);
                  _openForm(existing: printer);
                },
              ),
              if (!_adsFree)
                ListTile(
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: Text(
                    L.of(ctx)('Quitar publicidad (código)', 'Remove ads (code)'),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await showRedPosActivateDialog(
                      context: context,
                      store: widget.store,
                      address: printer.address,
                      onActivated: _reload,
                    );
                  },
                ),
              if (!printer.isDefault)
                ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: Text(
                    L.of(ctx)('Marcar predeterminada', 'Set as default'),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await widget.store.setDefault(printer.id);
                    await _reload();
                  },
                ),
              ListTile(
                leading: Icon(Icons.link_off,
                    color: Theme.of(ctx).colorScheme.error),
                title: Text(
                  L.of(ctx)('Desvincular', 'Unlink'),
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
      return const Center(
        child: RepaintBoundary(child: CircularProgressIndicator()),
      );
    }
    if (_printers.isEmpty) {
      return _EmptyState(
        showUsb: PlatformCaps.supportsUsb,
        onAdd: () => _openForm(),
        onOpenFile: _openSharedFile,
      );
    }
    return Column(
      children: [
        RedPosAdBanner(
          adsFree: _adsFree,
          store: widget.store,
          onActivated: _reload,
        ),
        Expanded(
          child: ListView.separated(
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
                      [
                        if (p.isDefault) L.of(context)('Predeterminada', 'Default'),
                        p.type.label,
                        p.paper.label,
                        if (!_adsFree) L.of(context)('con publicidad', 'with ads'),
                      ].join(' · '),
                    ),
                    trailing: busy
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: RepaintBoundary(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: L.of(context)('Opciones', 'Options'),
                            icon: const Icon(Icons.more_vert),
                            onPressed: () => _showPrinterActions(p),
                          ),
                    onTap: () => _showPrinterActions(p),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
    final l = L.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppBrand.name),
        actions: [
          IconButton(
            tooltip: l('Abrir archivo', 'Open file'),
            onPressed: _openSharedFile,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: l('Historial', 'History'),
            onPressed: () => _openHistory(),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: l('Actualizar', 'Refresh'),
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            tooltip: l('Ayuda y legal', 'Help and legal'),
            onSelected: (value) {
              final page = switch (value) {
                'help' => HelpScreen(store: widget.store),
                'terms' => const LegalScreen.terms(),
                'privacy' => const LegalScreen.privacy(),
                _ => null,
              };
              if (page == null) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => page),
              );
            },
            itemBuilder: (ctx) {
              final loc = L.of(ctx);
              return [
                PopupMenuItem(
                  value: 'help',
                  child: Text(loc('Ayuda y soporte', 'Help & support')),
                ),
                PopupMenuItem(
                  value: 'terms',
                  child: Text(loc('Términos y condiciones', 'Terms and conditions')),
                ),
                PopupMenuItem(
                  value: 'privacy',
                  child: Text(loc('Privacidad', 'Privacy')),
                ),
              ];
            },
          ),
        ],
      ),
      floatingActionButton: hideFab
          ? null
          : FloatingActionButton.extended(
              onPressed: _openingForm ? null : () => _openForm(),
              icon: const Icon(Icons.add),
              label: Text(l('Vincular', 'Pair')),
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
    final l = L.of(context);
    final types = showUsb
        ? '${PrinterLinkType.bluetooth.label}, ${PrinterLinkType.network.label} o ${PrinterLinkType.usb.label}'
            .replaceFirst(' o ', l(' o ', ' or '))
        : '${PrinterLinkType.bluetooth.label} ${l('o', 'or')} ${PrinterLinkType.network.label}';
    return BoletaPage(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final body = Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
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
                  l('Sin impresoras vinculadas', 'No printers paired'),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l(
                    'Vincula una impresora térmica ($types). '
                    'El historial de trabajos se ve en el icono de reloj o en las opciones de cada impresora.\n\n'
                    '${showUsb ? 'También puedes compartir un PDF hacia esta app desde otras apps.' : 'En iPhone/iPad imprime por WiFi (TCP 9100). Abre un PDF, XML o ZIP SUNAT con el botón de carpeta.'}',
                    'Pair a thermal printer ($types). '
                    'Job history is in the clock icon or each printer’s options.\n\n'
                    '${showUsb ? 'You can also share a PDF to this app from other apps.' : 'On iPhone/iPad print over WiFi (TCP 9100). Open a PDF, XML, or SUNAT ZIP with the folder button.'}',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_link),
                  label: Text(l('Vincular impresora', 'Pair printer')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onOpenFile,
                  icon: const Icon(Icons.folder_open),
                  label: Text(l('Abrir archivo', 'Open file')),
                ),
              ],
            ),
          );
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: body),
            ),
          );
        },
      ),
    );
  }
}
