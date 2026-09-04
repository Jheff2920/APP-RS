import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/cut_mode.dart';
import '../models/paper_width.dart';
import '../models/print_margins.dart';
import '../models/saved_printer.dart';
import '../services/print_service.dart';
import '../services/printer_permissions.dart';
import '../services/printer_store.dart';
import '../services/transports/printer_transport.dart';
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

class _PrinterFormScreenState extends State<PrinterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _portCtrl;

  /// ID fijo desde el primer frame (evita duplicar al Probar y luego Guardar).
  late final String _id;

  late PrinterLinkType _type;
  late PaperWidth _paper;
  late PrintMargins _margins;
  late CutMode _cut;
  late bool _isDefault;

  List<BluetoothInfo> _paired = [];
  bool _loadingPaired = false;
  bool _saving = false;
  bool _testing = false;
  bool _firstPrinter = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _id = e?.id ?? widget.store.newId();
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _portCtrl = TextEditingController(text: '${e?.port ?? 9100}');
    _type = e?.type ?? PrinterLinkType.bluetooth;
    _paper = e?.paper ?? PaperWidth.mm58;
    _margins = e?.margins ?? const PrintMargins();
    _cut = e?.cut ?? CutMode.fullGsV0;
    _isDefault = e?.isDefault ?? false;

    if (_type == PrinterLinkType.bluetooth) {
      _loadPaired();
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
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPaired() async {
    setState(() => _loadingPaired = true);
    try {
      final ok = await PrinterPermissions.ensureBluetooth();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Concede permisos de Bluetooth para listar dispositivos.',
              ),
            ),
          );
        }
        return;
      }
      final list = await PrintBluetoothThermal.pairedBluetooths;
      if (!mounted) return;
      setState(() => _paired = list);
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

  SavedPrinter _buildPrinter() {
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    return SavedPrinter(
      id: _id,
      name: _nameCtrl.text.trim(),
      type: _type,
      address: _addressCtrl.text.trim(),
      port: port,
      paper: _paper,
      margins: _margins,
      cut: _cut,
      isDefault: _isDefault || _firstPrinter,
    );
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
        const SnackBar(content: Text('Pagina de prueba enviada')),
      );
    } on PrinterTransportException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _testing = false);
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Configura conexión, rollo y márgenes antes de guardar. '
              'Así el diálogo Imprimir usará el ancho correcto (58 u 80 mm).',
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
            Text('Conexion', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<PrinterLinkType>(
              segments: const [
                ButtonSegment(
                  value: PrinterLinkType.bluetooth,
                  label: Text('Bluetooth'),
                  icon: Icon(Icons.bluetooth),
                ),
                ButtonSegment(
                  value: PrinterLinkType.network,
                  label: Text('WiFi'),
                  icon: Icon(Icons.wifi),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (set) {
                setState(() {
                  _type = set.first;
                  if (_type == PrinterLinkType.bluetooth) {
                    _loadPaired();
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            if (_type == PrinterLinkType.bluetooth) ...[
              Row(
                children: [
                  Text(
                    'Elegir dispositivo BT',
                    style: theme.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  IconButton(
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
              if (_paired.isEmpty && !_loadingPaired)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Empareja la impresora en Ajustes > Bluetooth, luego actualiza.',
                  ),
                ),
              ..._paired.map(
                (d) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.print),
                  title: Text(d.name),
                  subtitle: Text(d.macAdress),
                  selected: _addressCtrl.text == d.macAdress,
                  onTap: () {
                    setState(() {
                      _addressCtrl.text = d.macAdress;
                      if (_nameCtrl.text.trim().isEmpty) {
                        _nameCtrl.text = d.name;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
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
              'Elige 58 mm u 80 mm según el papel instalado en esta impresora '
              'antes de guardar. Esto define el tamaño en el diálogo Imprimir.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            PaperWidthSelector(
              value: _paper,
              onChanged: (v) => setState(() => _paper = v),
            ),
            const SizedBox(height: 8),
            Text(
              _paper == PaperWidth.mm80
                  ? 'Rollo 80 mm seleccionado (576 puntos).'
                  : 'Rollo 58 mm seleccionado (384 puntos).',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
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
            const SizedBox(height: 16),
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
              label: const Text('Probar impresion'),
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
    );
  }
}
