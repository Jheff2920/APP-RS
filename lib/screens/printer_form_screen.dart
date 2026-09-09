import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/cash_drawer.dart';
import '../models/cut_mode.dart';
import '../models/paper_width.dart';
import '../models/print_margins.dart';
import '../models/printer_dpi.dart';
import '../models/raster_scale.dart';
import '../models/saved_printer.dart';
import '../platform_caps.dart';
import '../services/bluetooth_bond_channel.dart';
import '../services/print_service.dart';
import '../services/printer_permissions.dart';
import '../services/printer_store.dart';
import '../services/usb_printer_channel.dart';
import '../services/transports/printer_transport.dart';
import '../widgets/boleta_page.dart';
import '../widgets/margin_fields.dart';
import '../widgets/paper_width_selector.dart';
import '../widgets/print_status_dialog.dart';

class PrinterFormScreen extends StatefulWidget {
  const PrinterFormScreen({
    super.key,
    required this.store,
    this.printService,
    this.existing,
  });

  final PrinterStore store;
  final PrintService? printService;
  final SavedPrinter? existing;

  @override
  State<PrinterFormScreen> createState() => _PrinterFormScreenState();
}

class _PrinterFormScreenState extends State<PrinterFormScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _portCtrl;

  /// ID fijo desde el primer frame (evita duplicar al Probar y luego Guardar).
  late final String _id;

  late PrinterLinkType _type;
  late PaperWidth _paper;
  late PrinterDpi _dpi;
  late PrintMargins _margins;
  late CutMode _cut;
  late CashDrawer _cashDrawer;
  late RasterScale _rasterScale;
  late bool _isDefault;

  List<BluetoothInfo> _paired = [];
  List<UsbDeviceInfo> _usbDevices = [];
  bool _loadingPaired = false;
  bool _loadingUsb = false;
  bool _saving = false;
  bool _testing = false;
  bool _firstPrinter = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final e = widget.existing;
    _id = e?.id ?? widget.store.newId();
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _portCtrl = TextEditingController(text: '${e?.port ?? 9100}');
    _type = e?.type ??
        (PlatformCaps.prefersNetworkDefault
            ? PrinterLinkType.network
            : PrinterLinkType.bluetooth);
    _paper = e?.paper ?? PaperWidth.mm58;
    _dpi = e?.dpi ?? PrinterDpi.dpi203;
    _margins = e?.margins ?? const PrintMargins();
    _cut = e?.cut ?? CutMode.fullGsV0;
    _cashDrawer = e?.cashDrawer ?? CashDrawer.none;
    _rasterScale = e?.rasterScale ?? RasterScale.x1;
    _isDefault = e?.isDefault ?? false;
    if (!PlatformCaps.supportsUsb && _type == PrinterLinkType.usb) {
      _type = PrinterLinkType.network;
      _addressCtrl.text = '';
    }

    if (_type == PrinterLinkType.bluetooth) {
      _loadPaired();
    } else if (_type == PrinterLinkType.usb) {
      _loadUsb();
    }
    _initDefaultFlag();
  }

  Future<void> _initDefaultFlag() async {
    if (_isEdit) return;
    final all = await widget.store.loadAll();
    if (!mounted) return;
    setState(() {
      _firstPrinter = all.isEmpty;
      if (_firstPrinter) _isDefault = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(BluetoothBondChannel.stopScan());
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _type == PrinterLinkType.bluetooth) {
      unawaited(_loadPaired());
    }
  }

  Future<void> _loadPaired() async {
    if (!mounted) return;
    setState(() => _loadingPaired = true);
    try {
      final ok = await PrinterPermissions.ensureBluetooth();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Concede permisos de Bluetooth para ver dispositivos emparejados.',
            ),
          ),
        );
        return;
      }
      if (PlatformCaps.isIOS) {
        final current = _addressCtrl.text.trim();
        final name = _nameCtrl.text.trim();
        setState(() {
          _paired = current.isEmpty
              ? const []
              : [
                  BluetoothInfo(
                    name: name.isEmpty ? current : name,
                    macAdress: current,
                  ),
                ];
        });
        return;
      }
      final bonded = await BluetoothBondChannel.listBonded();
      if (!mounted) return;
      setState(() {
        _paired = [
          for (final d in bonded)
            BluetoothInfo(
              name: d.name.isEmpty ? d.address : d.name,
              macAdress: d.address,
            ),
        ];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron listar BT: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPaired = false);
    }
  }

  Future<void> _pickPaired(BluetoothInfo device) async {
    setState(() {
      _addressCtrl.text = device.macAdress;
      if (_nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = device.name;
      }
    });
  }

  Future<void> _forgetPaired(BluetoothInfo device) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Olvidar Bluetooth'),
        content: Text(
          '¿Olvidar "${device.name}" del Bluetooth del teléfono?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Olvidar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await BluetoothBondChannel.forget(device.macAdress);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo olvidar del Bluetooth: $e')),
      );
      return;
    }
    if (!mounted) return;
    if (_addressCtrl.text.trim().toUpperCase() ==
        device.macAdress.trim().toUpperCase()) {
      _addressCtrl.clear();
    }
    await _loadPaired();
  }

  Future<void> _addNewBtDevice() async {
    final exclude = {
      for (final d in _paired) d.macAdress.trim().toUpperCase(),
    };
    final added = await showModalBottomSheet<_BtChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddBtDeviceSheet(excludeAddresses: exclude),
    );
    if (!mounted || added == null) return;
    if (PlatformCaps.isAndroid) {
      await _loadPaired();
    }
    if (!mounted) return;
    setState(() {
      final exists = _paired.any(
        (p) => p.macAdress.trim().toUpperCase() == added.address.toUpperCase(),
      );
      if (!exists) {
        _paired = [
          ..._paired,
          BluetoothInfo(name: added.name, macAdress: added.address),
        ];
      }
      _addressCtrl.text = added.address;
      if (_nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = added.name;
      }
    });
  }

  Future<void> _loadUsb() async {
    setState(() => _loadingUsb = true);
    try {
      final list = await UsbPrinterChannel.listDevices();
      if (!mounted) return;
      setState(() => _usbDevices = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron listar USB: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingUsb = false);
    }
  }

  Future<void> _pickUsb(UsbDeviceInfo d) async {
    try {
      final ok = await UsbPrinterChannel.requestPermission(d.address);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso USB denegado')),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _addressCtrl.text = d.address;
        if (_nameCtrl.text.trim().isEmpty) {
          _nameCtrl.text = d.name;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('USB: $e')),
        );
      }
    }
  }

  SavedPrinter _buildPrinter() {
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    return SavedPrinter(
      id: _id,
      name: _nameCtrl.text.trim(),
      type: _type,
      address: _addressCtrl.text.trim(),
      port: port,
      paper: _paper,
      dpi: _dpi,
      margins: _margins,
      cut: _cut,
      cashDrawer: _cashDrawer,
      rasterScale: _rasterScale,
      isDefault: _isDefault || _firstPrinter,
    );
  }

  Future<void> _persistSettings() async {
    if (!_isEdit || !_formKey.currentState!.validate()) return;
    await widget.store.upsert(_buildPrinter());
  }

  Future<void> _save({bool pop = true}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.store.upsert(_buildPrinter());
      if (!mounted) return;
      if (pop) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impresora guardada')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _testing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Mismo ID siempre → Probar no crea una segunda impresora.
      final printer = _buildPrinter();
      await widget.store.upsert(printer);
      if (!mounted) return;
      await runWithPrintStatusDialog(
        context: context,
        printerName: printer.name,
        job: (setPhase) => (widget.printService ?? PrintService()).printTestPage(
          printer,
          onPhase: setPhase,
        ),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Página de prueba enviada')),
      );
    } on PrinterTransportException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  List<PrinterLinkType> get _linkTypes {
    if (PlatformCaps.supportsUsb) {
      return PrinterLinkType.values;
    }
    return const [PrinterLinkType.bluetooth, PrinterLinkType.network];
  }

  IconData _iconFor(PrinterLinkType type) {
    switch (type) {
      case PrinterLinkType.bluetooth:
        return Icons.bluetooth;
      case PrinterLinkType.network:
        return Icons.wifi;
      case PrinterLinkType.usb:
        return Icons.usb;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar impresora' : 'Agregar impresora'),
      ),
      body: Form(
        key: _formKey,
        child: BoletaPage(
          bottomBar: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: (_saving || _testing) ? null : () => _save(),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: (_saving || _testing) ? null : _test,
                icon: _testing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print),
                label: const Text('Probar impresión'),
              ),
            ],
          ),
          child: ListView(
          padding: const EdgeInsets.all(16),
          scrollCacheExtent: const ScrollCacheExtent.pixels(280),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Text(
              PlatformCaps.supportsSystemPrint
                  ? 'Configura conexión, rollo y márgenes antes de guardar. '
                      'Así el diálogo Imprimir usará el ancho correcto (58 u 80 mm).'
                  : 'Configura conexión, rollo y márgenes antes de guardar. '
                      'En iPhone/iPad el camino fiable es WiFi (IP y puerto 9100).',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Caja 1 / Cocina',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Escribe un nombre';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Conexión', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<PrinterLinkType>(
              showSelectedIcon: false,
              segments: [
                for (final t in _linkTypes)
                  ButtonSegment(
                    value: t,
                    label: Text(t.label),
                    icon: Icon(_iconFor(t)),
                  ),
              ],
              selected: {_type},
              onSelectionChanged: (set) {
                setState(() {
                  _type = set.first;
                  if (_type == PrinterLinkType.bluetooth) {
                    _loadPaired();
                  } else if (_type == PrinterLinkType.usb) {
                    unawaited(BluetoothBondChannel.stopScan());
                    _loadUsb();
                  } else {
                    unawaited(BluetoothBondChannel.stopScan());
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            if (_type == PrinterLinkType.bluetooth) ...[
              Row(
                children: [
                  Text(
                    'Dispositivos emparejados',
                    style: theme.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Actualizar emparejados',
                    onPressed: _loadingPaired ? null : _loadPaired,
                    icon: _loadingPaired
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  PlatformCaps.isIOS
                      ? 'Aquí solo ves el equipo que ya elegiste. Para buscar una impresora BLE cercana usa Agregar dispositivo.'
                      : 'Aquí solo salen impresoras ya vinculadas. Para una nueva, usa Agregar dispositivo.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (_paired.isEmpty && !_loadingPaired)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('No hay dispositivos emparejados.'),
                ),
              ..._paired.map(
                (d) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.print),
                  title: Text(d.name),
                  subtitle: Text(d.macAdress),
                  selected: _addressCtrl.text.toUpperCase() ==
                      d.macAdress.toUpperCase(),
                  trailing: PlatformCaps.isAndroid
                      ? IconButton(
                          tooltip: 'Olvidar del Bluetooth',
                          icon: const Icon(Icons.link_off),
                          onPressed: () => _forgetPaired(d),
                        )
                      : null,
                  onTap: () => _pickPaired(d),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loadingPaired ? null : _addNewBtDevice,
                icon: const Icon(Icons.add),
                label: const Text('Agregar dispositivo'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Direccion MAC',
                  hintText: 'AA:BB:CC:DD:EE:FF',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Selecciona o escribe la MAC';
                  }
                  return null;
                },
              ),
            ] else if (_type == PrinterLinkType.usb) ...[
              Row(
                children: [
                  Text(
                    'Elegir impresora USB',
                    style: theme.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadingUsb ? null : _loadUsb,
                    icon: _loadingUsb
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'En IMIN/Falcon usa USB (impresora integrada), no Bluetooth. '
                  'Concede el permiso al elegir el dispositivo.',
                ),
              ),
              if (_usbDevices.isEmpty && !_loadingUsb)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('No hay dispositivos USB con salida de impresora.'),
                ),
              ..._usbDevices.map(
                (d) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.usb),
                  title: Text(d.name),
                  subtitle: Text(
                    '${d.address}${d.hasPermission ? '' : ' · sin permiso'}',
                  ),
                  selected: _addressCtrl.text == d.address,
                  onTap: () => _pickUsb(d),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'USB vid:pid',
                  hintText: '1137:85',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Selecciona un dispositivo USB';
                  }
                  return null;
                },
              ),
            ] else ...[
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'IP de la impresora',
                  hintText: '192.168.1.50',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Escribe la IP';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portCtrl,
                decoration: const InputDecoration(
                  labelText: 'Puerto TCP',
                  hintText: '9100',
                  helperText: 'Puerto tipico ESC/POS: 9100',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 1 || n > 65535) {
                    return 'Puerto invalido';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            Text('Ancho del rollo', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              PlatformCaps.supportsSystemPrint
                  ? 'Elige 58 mm u 80 mm según el papel instalado en esta impresora '
                      'antes de guardar. Esto define el tamaño en el diálogo Imprimir.'
                  : 'Elige 58 mm u 80 mm según el papel instalado en esta impresora.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            PaperWidthSelector(
              value: _paper,
              onChanged: (v) => setState(() => _paper = v),
            ),
            const SizedBox(height: 8),
            Text(
              '${_paper.label} · ${_dpi.label} · ${_dpi.dotsFor(_paper)} puntos',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text('DPI del cabezal', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '203 es lo normal. 300 solo si la impresora es 300 dpi; '
              'si el ticket sale partido, vuelve a 203.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<PrinterDpi>(
              segments: [
                for (final d in PrinterDpi.values)
                  ButtonSegment(value: d, label: Text(d.label)),
              ],
              selected: {_dpi},
              onSelectionChanged: (set) {
                if (set.isEmpty) return;
                setState(() => _dpi = set.first);
                _persistSettings();
              },
            ),
            const SizedBox(height: 6),
            Text(_dpi.hint, style: theme.textTheme.labelMedium),
            const SizedBox(height: 20),
            MarginFields(
              value: _margins,
              onChanged: (v) => setState(() => _margins = v),
            ),
            const SizedBox(height: 20),
            Text('Corte automatico', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Con cuchilla: al terminar se aplica el margen inferior y luego el corte. '
              'Sin cuchilla: elige «Sin corte» (solo avance).',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            DropdownMenu<CutMode>(
              initialSelection: _cut,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Comando de corte'),
              dropdownMenuEntries: CutMode.values
                  .map(
                    (m) => DropdownMenuEntry(
                      value: m,
                      label: m.label,
                    ),
                  )
                  .toList(),
              onSelected: (v) {
                if (v != null) setState(() => _cut = v);
              },
            ),
            if (_cut != CutMode.none) ...[
              const SizedBox(height: 6),
              Text(_cut.hint, style: theme.textTheme.labelMedium),
            ],
            const SizedBox(height: 20),
            Text('Gaveta de dinero', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              PlatformCaps.supportsUsb
                  ? 'Opcional: el pulso se envía cuando el ticket ya salió. '
                      'En Falcon/USB la gaveta es del equipo (GPIO), no del cable USB. '
                      'Elige Pin 2 o Pin 5. Si no hay cajón, deja «Sin gaveta».'
                  : 'Opcional: el pulso ESC/POS se envía cuando el ticket ya salió. '
                      'Elige Pin 2 o Pin 5. Si no hay cajón, deja «Sin gaveta».',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            DropdownMenu<CashDrawer>(
              initialSelection: _cashDrawer,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Comando de gaveta'),
              dropdownMenuEntries: CashDrawer.values
                  .map(
                    (m) => DropdownMenuEntry(
                      value: m,
                      label: m.label,
                    ),
                  )
                  .toList(),
              onSelected: (v) {
                if (v != null) setState(() => _cashDrawer = v);
              },
            ),
            if (_cashDrawer != CashDrawer.none) ...[
              const SizedBox(height: 6),
              Text(_cashDrawer.hint, style: theme.textTheme.labelMedium),
            ],
            const SizedBox(height: 20),
            Text('Nitidez', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'x1, x2 y x3 imprimen al mismo tamaño (384/576). '
              'x2 y x3 solo afinan el dibujo; tardan un poco mas.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<RasterScale>(
              segments: [
                for (final s in RasterScale.values)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {_rasterScale},
              onSelectionChanged: (set) {
                if (set.isEmpty) return;
                setState(() => _rasterScale = set.first);
                _persistSettings();
              },
            ),
            const SizedBox(height: 6),
            Text(_rasterScale.hint, style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar como predeterminada'),
              subtitle: Text(
                _firstPrinter
                    ? 'Primera impresora: será la predeterminada'
                    : 'Se usará por defecto al imprimir',
              ),
              value: _isDefault || _firstPrinter,
              onChanged: _firstPrinter
                  ? null
                  : (v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: 24),
            Text(
              'La vista previa del sistema puede verse angosta en 80 mm si el PDF '
              'del POS es de 58 mm; la impresión real usa el ancho que elegiste aquí.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _BtChoice {
  const _BtChoice({
    required this.name,
    required this.address,
    required this.bonded,
  });

  final String name;
  final String address;
  final bool bonded;
}

class _AddBtDeviceSheet extends StatefulWidget {
  const _AddBtDeviceSheet({required this.excludeAddresses});

  final Set<String> excludeAddresses;

  @override
  State<_AddBtDeviceSheet> createState() => _AddBtDeviceSheetState();
}

class _AddBtDeviceSheetState extends State<_AddBtDeviceSheet> {
  final Map<String, NearbyBtDevice> _nearby = {};
  final ValueNotifier<List<NearbyBtDevice>> _found =
      ValueNotifier<List<NearbyBtDevice>>(const []);
  StreamSubscription<Map<String, dynamic>>? _events;
  Timer? _flush;
  bool _scanning = false;
  String? _bonding;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _flush?.cancel();
    _events?.cancel();
    _found.dispose();
    unawaited(BluetoothBondChannel.stopScan());
    super.dispose();
  }

  void _publishFound() {
    final list = _nearby.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _found.value = list;
  }

  Future<void> _start() async {
    _flush?.cancel();
    _nearby.clear();
    _found.value = const [];
    setState(() {
      _scanning = true;
      _error = null;
    });
    final ok = await PrinterPermissions.ensureBluetooth(
      forDiscovery: PlatformCaps.isAndroid,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _scanning = false;
        _error =
            'Concede Bluetooth y ubicación para buscar dispositivos cercanos.';
      });
      return;
    }
    if (PlatformCaps.isIOS) {
      try {
        final list = await PrintBluetoothThermal.pairedBluetooths;
        if (!mounted) return;
        for (final d in list) {
          final key = d.macAdress.trim().toUpperCase();
          if (key.isEmpty || widget.excludeAddresses.contains(key)) continue;
          _nearby[key] = NearbyBtDevice(
            name: d.name,
            address: d.macAdress.trim(),
            bonded: false,
          );
        }
        _publishFound();
        setState(() => _scanning = false);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _scanning = false;
          _error = 'No se pudieron buscar dispositivos: $e';
        });
      }
      return;
    }

    _events?.cancel();
    _events = BluetoothBondChannel.events().listen((map) {
      if (!mounted) return;
      final type = map['type'] as String? ?? '';
      if (type == 'found') {
        final device = NearbyBtDevice(
          name: map['name'] as String? ?? '',
          address: map['address'] as String? ?? '',
          bonded: map['bonded'] as bool? ?? false,
        );
        if (device.address.isEmpty || device.bonded) return;
        if (widget.excludeAddresses.contains(device.key)) return;
        _nearby[device.key] = device;
        _flush?.cancel();
        _flush = Timer(const Duration(milliseconds: 180), () {
          if (mounted) _publishFound();
        });
      } else if (type == 'scanFinished') {
        _flush?.cancel();
        _publishFound();
        setState(() => _scanning = false);
      }
    });
    try {
      final started = await BluetoothBondChannel.startScan();
      if (mounted) setState(() => _scanning = started);
    } on BluetoothBondException catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = e.message;
      });
      if (e.code == 'location_off') {
        unawaited(BluetoothBondChannel.openLocationSettings());
      }
    }
  }

  Future<void> _select(NearbyBtDevice device) async {
    if (_bonding != null) return;
    if (PlatformCaps.isAndroid) {
      setState(() => _bonding = device.address);
      try {
        await BluetoothBondChannel.createBond(device.address);
      } on BluetoothBondException catch (e) {
        if (!mounted) return;
        setState(() => _bonding = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() => _bonding = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('BT: $e')),
        );
        return;
      }
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      _BtChoice(
        name: device.name,
        address: device.address,
        bonded: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Agregar dispositivo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              PlatformCaps.isIOS
                  ? 'Busca impresoras BLE cercanas. Toca una para usarla.'
                  : 'Enciende la impresora. Toca una para emparejarla. El PIN suele ser 0000 o 1234.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (_scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    RepaintBoundary(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Buscando cercanos…'),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ValueListenableBuilder<List<NearbyBtDevice>>(
              valueListenable: _found,
              builder: (context, found, _) {
                return SizedBox(
                  height: 280,
                  child: found.isEmpty
                      ? (!_scanning && _error == null
                          ? const Center(
                              child: Text(
                                'No se encontraron dispositivos nuevos. Acerca la impresora y actualiza.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : const SizedBox.shrink())
                      : ListView.builder(
                          scrollCacheExtent:
                              const ScrollCacheExtent.pixels(160),
                          itemCount: found.length,
                          itemBuilder: (context, index) {
                            final d = found[index];
                            return RepaintBoundary(
                              child: ListTile(
                                dense: true,
                                enabled: _bonding == null,
                                leading: _bonding == d.address
                                    ? const RepaintBoundary(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.bluetooth_searching),
                                title: Text(d.name),
                                subtitle: Text(d.address),
                                onTap: _bonding != null
                                    ? null
                                    : () => _select(d),
                              ),
                            );
                          },
                        ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _bonding != null
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: (_scanning || _bonding != null) ? null : _start,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Buscar de nuevo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

