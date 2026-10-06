import 'dart:async';
import 'dart:math' as math;

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
import '../theme.dart';
import '../widgets/print_status_dialog.dart';
import '../widgets/printer_card.dart';
import '../widgets/redpos_ad_banner.dart';
import '../widgets/ui_kit.dart';
import 'help_screen.dart';
import 'print_history_screen.dart';
import 'printer_form_screen.dart';
import 'share_print_screen.dart';
import 'legal_screen.dart';
import 'privacy_data_screen.dart';
import 'custom_tickets_list_screen.dart';
import 'sunat_print_settings_screen.dart';

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
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
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

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _openTickets() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomTicketsListScreen(
          printerStore: widget.store,
          printService: widget.printService,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openSunat() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SunatPrintSettingsScreen(printerStore: widget.store),
      ),
    );
    if (mounted) await _reload();
  }

  void _showPrinterActions(SavedPrinter printer) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final l = L.of(ctx);
        final tt = Theme.of(ctx).textTheme;
        void run(VoidCallback action) {
          Navigator.pop(ctx);
          action();
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconTile(
                      icon: printerTypeIcon(printer.type),
                      color: printerTypeColor(printer.type),
                      size: 52,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(printer.name, style: tt.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            '${printer.type.label}, ${printer.paper.label}\n'
                            '${printer.connectionSummary}',
                            style: tt.bodySmall
                                ?.copyWith(color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionGroup(
                  dividerIndent: 68,
                  children: [
                    NavRow(
                      icon: Icons.print_outlined,
                      title: l('Imprimir página de prueba', 'Print test page'),
                      onTap: () => run(() => _testPrint(printer)),
                    ),
                    NavRow(
                      icon: Icons.tune_rounded,
                      title: l('Ajustes de la impresora', 'Printer settings'),
                      subtitle: l(
                        'Papel, márgenes, corte y gaveta',
                        'Paper, margins, cut and drawer',
                      ),
                      onTap: () => run(() => _openForm(existing: printer)),
                    ),
                    NavRow(
                      icon: Icons.history_rounded,
                      title: l('Historial de esta impresora', 'History for this printer'),
                      onTap: () => run(() => _openHistory(printer: printer)),
                    ),
                    if (!printer.isDefault)
                      NavRow(
                        icon: Icons.star_outline_rounded,
                        title: l('Usar como principal', 'Make default'),
                        subtitle: l(
                          'Se elige primero al imprimir',
                          'Picked first when printing',
                        ),
                        onTap: () => run(() async {
                          await widget.store.setDefault(printer.id);
                          await _reload();
                        }),
                      ),
                    if (!_adsFree)
                      NavRow(
                        icon: Icons.vpn_key_outlined,
                        title: l('Tengo un código', 'I have a code'),
                        subtitle: l('Quita la publicidad', 'Removes ads'),
                        onTap: () => run(() {
                          showRedPosActivateDialog(
                            context: context,
                            store: widget.store,
                            address: printer.address,
                            onActivated: _reload,
                          );
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionGroup(
                  children: [
                    NavRow(
                      icon: Icons.link_off_rounded,
                      title: l('Desvincular', 'Unlink'),
                      destructive: true,
                      showChevron: false,
                      onTap: () => run(() => _unlink(printer)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  SavedPrinter? get _mainPrinter =>
      _printers.isEmpty ? null : PrinterStore.findByIdOrDefault(_printers, '');

  Widget _homeBody({bool balance = true}) {
    if (_loading) {
      return const Center(
        child: RepaintBoundary(child: CircularProgressIndicator()),
      );
    }
    final l = L.of(context);
    final main = _mainPrinter;
    final bottomPad = 32 + MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: _BalancedFill(
          viewportHeight: balance ? constraints.maxHeight - bottomPad : 0,
          color: AppColors.brand,
          header: const _BrandHeader(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _homeChildren(l, main, compact: !balance),
          ),
        ),
      ),
    );
  }

  List<Widget> _homeChildren(L l, SavedPrinter? main, {required bool compact}) {
    return [
        _ReceiptHero(
          printer: main,
          busy: main != null && _busyId == main.id,
          showUsb: PlatformCaps.supportsUsb,
          onOpenFile: _openSharedFile,
          onTest: main == null ? null : () => _testPrint(main),
          onOptions: main == null ? null : () => _showPrinterActions(main),
          onAdd: _openingForm ? null : () => _openForm(),
          showAddAnother: _printers.length == 1,
          compact: compact,
        ),
        _Centered(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_printers.length > 1) ...[
                SectionLabel(
                  l(
                    'Impresoras (${_printers.length})',
                    'Printers (${_printers.length})',
                  ),
                  trailing: TextButton.icon(
                    onPressed: _openingForm ? null : () => _openForm(),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(l('Vincular', 'Pair')),
                  ),
                  padding: const EdgeInsets.fromLTRB(4, 14, 0, 4),
                ),
                for (final p in _printers) ...[
                  RepaintBoundary(
                    child: PrinterCard(
                      printer: p,
                      busy: _busyId == p.id,
                      onTestPrint: () => _testPrint(p),
                      onOptions: () => _showPrinterActions(p),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              SectionLabel(l('Herramientas', 'Tools')),
              _ToolsRow(
                tools: [
                  _Tool(
                    icon: Icons.receipt_long_outlined,
                    label: l('Ticket SUNAT', 'SUNAT ticket'),
                    onTap: _openSunat,
                  ),
                  _Tool(
                    icon: Icons.edit_note_rounded,
                    label: l('Tickets propios', 'Custom tickets'),
                    locked: !_adsFree,
                    onTap: _openTickets,
                  ),
                  _Tool(
                    icon: Icons.history_rounded,
                    label: l('Historial', 'History'),
                    onTap: () => _openHistory(),
                  ),
                  _Tool(
                    icon: Icons.support_agent_rounded,
                    label: l('Ayuda', 'Help'),
                    onTap: () => _openPage(HelpScreen(store: widget.store)),
                  ),
                ],
              ),
              if (!_adsFree) ...[
                const SizedBox(height: 20),
                RedPosAdBanner(
                  adsFree: _adsFree,
                  store: widget.store,
                  onActivated: _reload,
                ),
              ],
            ],
          ),
        ),
    ];
  }

  Widget _detailPane() {
    final base = Theme.of(context);
    // Cabecera clara en el panel: evita dos barras moradas apiladas.
    final panelTheme = base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        iconTheme: const IconThemeData(color: AppColors.ink),
        actionsIconTheme: const IconThemeData(color: AppColors.inkSoft),
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
          color: AppColors.ink,
          fontSize: 18,
        ),
        toolbarHeight: 64,
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
      ),
    );
    // Sin esto, Atrás de Android cierra la app aunque el panel tenga una pantalla abierta.
    return NavigatorPopHandler(
      onPopWithResult: (_) => _detailNavKey.currentState?.maybePop(),
      child: Theme(
        data: panelTheme,
        child: Navigator(
          key: _detailNavKey,
          onGenerateRoute: (settings) {
            return MaterialPageRoute<void>(
              builder: (context) => const _DetailPlaceholder(),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded;
    final l = L.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppBrand.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: l('Ayuda y legal', 'Help and legal'),
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              final Widget? page = switch (value) {
                'help' => HelpScreen(store: widget.store),
                'privacy_data' => PrivacyDataScreen(store: widget.store),
                'terms' => const LegalScreen.terms(),
                'privacy' => const LegalScreen.privacy(),
                _ => null,
              };
              if (page != null) _openPage(page);
            },
            itemBuilder: (ctx) {
              final loc = L.of(ctx);
              return [
                PopupMenuItem(
                  value: 'help',
                  child: Text(loc('Ayuda y soporte', 'Help & support')),
                ),
                PopupMenuItem(
                  value: 'privacy_data',
                  child: Text(loc('Datos y privacidad', 'Data & privacy')),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'terms',
                  child: Text(
                    loc('Términos y condiciones', 'Terms and conditions'),
                  ),
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
      body: expanded
          ? Stack(
              children: [
                // La franja morada cruza ambas columnas; ticket y panel
                // salen de ella a la misma altura.
                Container(height: _ReceiptHero.compactBand, color: AppColors.brand),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 440, child: _homeBody(balance: false)),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          0,
                          _ReceiptHero.compactPaperTop,
                          16,
                          16 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: _DetailSheet(child: _detailPane()),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : _homeBody(),
    );
  }
}

/// Si el contenido es más bajo que la pantalla (tablet en vertical), lo baja
/// hasta quedar equilibrado y pinta el hueco superior con [color], para que el
/// ticket siga saliendo de la franja morada.
class _BalancedFill extends MultiChildRenderObjectWidget {
  _BalancedFill({
    required this.viewportHeight,
    required this.color,
    required Widget child,
    required Widget header,
  }) : super(children: [child, header]);

  final double viewportHeight;
  final Color color;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBalancedFill(viewportHeight, color);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBalancedFill renderObject,
  ) {
    renderObject
      ..viewportHeight = viewportHeight
      ..color = color;
  }
}

class _BalancedParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderBalancedFill extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BalancedParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BalancedParentData> {
  _RenderBalancedFill(this._viewportHeight, this._color);

  static const _topShare = 0.5;
  static const _headerMargin = 24.0;

  double _viewportHeight;
  set viewportHeight(double v) {
    if (v == _viewportHeight) return;
    _viewportHeight = v;
    markNeedsLayout();
  }

  Color _color;
  set color(Color v) {
    if (v == _color) return;
    _color = v;
    markNeedsPaint();
  }

  double _top = 0;
  bool _showHeader = false;

  RenderBox get _content => firstChild!;
  RenderBox get _header => childAfter(firstChild!)!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BalancedParentData) {
      child.parentData = _BalancedParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    _content.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    final free = math.max(0.0, _viewportHeight - _content.size.height);
    _top = (free * _topShare).roundToDouble();
    (_content.parentData! as BoxParentData).offset = Offset(0, _top);

    _header.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    final h = _header.size;
    _showHeader = h.height + _headerMargin * 2 <= _top;
    (_header.parentData! as BoxParentData).offset = Offset(
      ((width - h.width) / 2).roundToDouble(),
      ((_top - h.height) / 2).roundToDouble(),
    );

    size = constraints.constrain(Size(width, _content.size.height + free));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_top > 0) {
      context.canvas.drawRect(
        Rect.fromLTWH(offset.dx, offset.dy, size.width, _top + 1),
        Paint()..color = _color,
      );
    }
    if (_showHeader) {
      final o = (_header.parentData! as BoxParentData).offset;
      context.paintChild(_header, offset + o);
    }
    final c = (_content.parentData! as BoxParentData).offset;
    context.paintChild(_content, offset + c);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = (_content.parentData! as BoxParentData).offset;
    final hitContent = result.addWithPaintOffset(
      offset: c,
      position: position,
      hitTest: (r, p) => _content.hitTest(r, position: p),
    );
    if (hitContent || !_showHeader) return hitContent;
    final o = (_header.parentData! as BoxParentData).offset;
    return result.addWithPaintOffset(
      offset: o,
      position: position,
      hitTest: (r, p) => _header.hitTest(r, position: p),
    );
  }
}

/// Marca en la franja morada cuando sobra alto (tablet en vertical).
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tt = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/brand/rs_mark.png',
            width: 132,
            height: 132,
            filterQuality: FilterQuality.medium,
          ),
          Text(
            l('Impresión térmica para tu negocio',
                'Thermal printing for your business'),
            style: tt.titleLarge?.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Red Soluciones',
            style: tt.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ancho máximo de lectura y margen lateral para el contenido del inicio.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
      ),
    );
  }
}

/// Panel derecho en tablet: hoja redondeada que sale de la franja morada a la
/// misma altura que el ticket.
class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      position: DecorationPosition.background,
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.line),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// El ticket sale de la "ranura" morada del AppBar: la impresora principal
/// y sus dos acciones, o la invitación a vincular la primera.
class _ReceiptHero extends StatelessWidget {
  const _ReceiptHero({
    required this.printer,
    required this.busy,
    required this.showUsb,
    required this.onOpenFile,
    required this.onTest,
    required this.onOptions,
    required this.onAdd,
    required this.showAddAnother,
    this.compact = false,
  });

  final SavedPrinter? printer;
  final bool busy;
  final bool showUsb;
  final VoidCallback onOpenFile;
  final VoidCallback? onTest;
  final VoidCallback? onOptions;
  final VoidCallback? onAdd;
  final bool showAddAnother;
  final bool compact;

  /// Alto de la franja morada bajo el AppBar y punto donde empieza el papel.
  static const bandHeight = 52.0;
  static const paperTop = 46.0;

  /// Tablet horizontal: franja baja para que el morado no ocupe tanto.
  static const compactBand = 22.0;
  static const compactPaperTop = 16.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(height: compact ? compactBand : bandHeight, color: AppColors.brand),
        _Centered(
          child: Padding(
            padding: EdgeInsets.only(top: compact ? compactPaperTop : paperTop),
            child: PhysicalShape(
              clipper: const TornPaperClipper(topRadius: 20),
              color: AppColors.paper,
              elevation: 3,
              shadowColor: AppColors.brand.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                child: printer == null
                    ? _emptyContent(context)
                    : _printerContent(context, printer!),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _printerContent(BuildContext context, SavedPrinter p) {
    final l = L.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l('Impresora principal', 'Default printer'),
                    style: tt.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.name,
                    style: tt.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        printerTypeIcon(p.type),
                        size: 18,
                        color: printerTypeColor(p.type),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${p.type.label}, ${p.paper.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium
                              ?.copyWith(color: AppColors.inkSoft),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: l('Opciones de la impresora', 'Printer options'),
              onPressed: busy ? null : onOptions,
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _DottedRule(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final open = FilledButton.icon(
              onPressed: onOpenFile,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(l('Imprimir archivo', 'Print a file')),
            );
            final test = OutlinedButton.icon(
              onPressed: busy ? null : onTest,
              icon: busy
                  ? const ButtonSpinner()
                  : const Icon(Icons.print_outlined),
              label: Text(l('Probar', 'Test')),
            );
            if (c.maxWidth < 340) {
              // Teléfono: una acción fuerte y las secundarias como enlaces.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  open,
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: busy ? null : onTest,
                        icon: busy
                            ? const ButtonSpinner()
                            : const Icon(Icons.print_outlined, size: 20),
                        label: Text(l('Probar', 'Test')),
                      ),
                      if (showAddAnother)
                        TextButton.icon(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: Text(l('Vincular otra', 'Pair another')),
                        ),
                    ],
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(flex: 3, child: open),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: test),
                  ],
                ),
                if (showAddAnother) ...[
                  const SizedBox(height: 6),
                  Align(
                    child: TextButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(
                        l('Vincular otra impresora', 'Pair another printer'),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _emptyContent(BuildContext context) {
    final l = L.of(context);
    final tt = Theme.of(context).textTheme;
    final types = showUsb
        ? l('Bluetooth, WiFi / Red o USB', 'Bluetooth, WiFi / Network or USB')
        : l('Bluetooth o WiFi / Red', 'Bluetooth or WiFi / Network');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l('Sin impresoras todavía', 'No printers yet'),
          style: tt.bodySmall?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 4),
        Text(
          l('Vincula tu impresora térmica', 'Pair your thermal printer'),
          style: tt.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          l(
            'Funciona por $types, con rollos de 58 u 80 mm. '
                'Luego imprimes boletas y facturas con un toque.',
            'Works over $types, with 58 or 80 mm rolls. '
                'Then print receipts with one tap.',
          ),
          style: tt.bodyMedium?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        const _DottedRule(),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_link_rounded),
          label: Text(l('Vincular impresora', 'Pair printer')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onOpenFile,
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(l('Abrir archivo', 'Open file')),
        ),
      ],
    );
  }
}

class _DottedRule extends StatelessWidget {
  const _DottedRule();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 2),
      painter: _DottedPainter(),
    );
  }
}

class _DottedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const gap = 5.0;
    var x = 1.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1), Offset(x + dash, 1), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DottedPainter oldDelegate) => false;
}

class _Tool {
  const _Tool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool locked;
}

/// Accesos directos en una sola franja; en tablet el texto va al lado.
class _ToolsRow extends StatelessWidget {
  const _ToolsRow({required this.tools});

  final List<_Tool> tools;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in tools)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: t.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconTile(icon: t.icon, size: 48),
                            if (t.locked)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: AppColors.paper,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.line),
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    size: 11,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ColoredBox(
      color: AppColors.paper,
      child: Center(
        child: SingleChildScrollView(
          child: EmptyMessage(
          icon: Icons.tune_rounded,
          title: l('Ajustes y detalle', 'Settings and details'),
          body: l(
            'Los ajustes de la impresora, el historial y el formulario para '
                'vincular se abren en este lado.',
            'Printer settings, history and the pairing form open on this side.',
          ),
          ),
        ),
      ),
    );
  }
}
