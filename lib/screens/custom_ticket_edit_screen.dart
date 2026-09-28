import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../services/custom_ticket/custom_ticket.dart';
import '../services/custom_ticket/custom_ticket_store.dart';
import '../services/print_service.dart';
import '../services/printer_store.dart';
import '../services/sunat/sunat_logo.dart';
import '../widgets/boleta_page.dart';
import 'custom_ticket_preview_screen.dart';

class CustomTicketEditScreen extends StatefulWidget {
  const CustomTicketEditScreen({
    super.key,
    required this.store,
    required this.templateId,
    required this.printerStore,
    required this.printService,
  });

  final CustomTicketStore store;
  final String templateId;
  final PrinterStore printerStore;
  final PrintService printService;

  @override
  State<CustomTicketEditScreen> createState() => _CustomTicketEditScreenState();
}

class _CustomTicketEditScreenState extends State<CustomTicketEditScreen> {
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  final _subtotalCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _subtotalLabelCtrl = TextEditingController(text: 'Op. Gravada');
  final _taxLabelCtrl = TextEditingController(text: 'IGV 18%');
  final _totalLabelCtrl = TextEditingController(text: 'TOTAL');
  final _currencyCtrl = TextEditingController(text: 'S/');
  final _qrCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();

  var _loading = true;
  var _saving = false;
  var _savingLogo = false;
  var _missing = false;
  var _showLogo = false;
  var _showTotals = true;
  var _showQr = false;
  var _showBarcode = false;
  Uint8List? _logo;
  List<CustomTicketLine> _lines = [];
  String _id = '';
  /// Si el usuario edita totales a mano, no pisar hasta que cambien líneas o pulse Recalcular.
  var _totalsManual = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _footerCtrl.dispose();
    _subtotalCtrl.dispose();
    _taxCtrl.dispose();
    _totalCtrl.dispose();
    _subtotalLabelCtrl.dispose();
    _taxLabelCtrl.dispose();
    _totalLabelCtrl.dispose();
    _currencyCtrl.dispose();
    _qrCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final t = await widget.store.loadById(widget.templateId);
    if (!mounted) return;
    if (t == null) {
      setState(() {
        _missing = true;
        _loading = false;
      });
      return;
    }
    _id = t.id;
    _nameCtrl.text = t.name;
    _titleCtrl.text = t.title;
    _footerCtrl.text = t.footer;
    _subtotalCtrl.text = t.subtotal;
    _taxCtrl.text = t.tax;
    _totalCtrl.text = t.total;
    _subtotalLabelCtrl.text = t.subtotalLabel;
    _taxLabelCtrl.text = t.taxLabel;
    _totalLabelCtrl.text = t.totalLabel;
    _currencyCtrl.text = t.currencySymbol;
    _qrCtrl.text = t.qrData;
    _barcodeCtrl.text = t.barcodeData;
    setState(() {
      _showLogo = t.showLogo;
      _showTotals = t.showTotals;
      _showQr = t.showQr;
      _showBarcode = t.showBarcode;
      _logo = t.logoBytes;
      _lines = List.of(t.lines);
      _loading = false;
    });
    final hasTotals = t.subtotal.trim().isNotEmpty ||
        t.tax.trim().isNotEmpty ||
        t.total.trim().isNotEmpty;
    if (!hasTotals) {
      _recalcTotals(force: true);
    } else {
      // Valores guardados: formatear dinero y dejar auto hasta que edite a mano.
      _subtotalCtrl.text = CustomTicketMoney.formatRaw(t.subtotal);
      _taxCtrl.text = CustomTicketMoney.formatRaw(t.tax);
      _totalCtrl.text = CustomTicketMoney.formatRaw(t.total);
      _totalsManual = false;
    }
  }

  CustomTicketTemplate _current() {
    return CustomTicketTemplate(
      id: _id,
      name: _nameCtrl.text,
      title: _titleCtrl.text,
      lines: List.of(_lines),
      showLogo: _showLogo,
      logoBytes: _logo,
      footer: _footerCtrl.text,
      showTotals: _showTotals,
      currencySymbol: _currencyCtrl.text,
      subtotalLabel: _subtotalLabelCtrl.text,
      subtotal: _subtotalCtrl.text,
      taxLabel: _taxLabelCtrl.text,
      tax: _taxCtrl.text,
      totalLabel: _totalLabelCtrl.text,
      total: _totalCtrl.text,
      showQr: _showQr,
      qrData: _qrCtrl.text,
      showBarcode: _showBarcode,
      barcodeData: _barcodeCtrl.text,
    );
  }

  Future<void> _persist() async {
    if (_id.isEmpty) return;
    await widget.store.save(_current());
  }

  Future<void> _saveAndClose() async {
    setState(() => _saving = true);
    try {
      await _persist();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _preview() async {
    await _persist();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CustomTicketPreviewScreen(
          template: _current(),
          printerStore: widget.printerStore,
          printService: widget.printService,
        ),
      ),
    );
  }

  Future<void> _pickLogo() async {
    final l = L.of(context);
    setState(() => _savingLogo = true);
    await Future<void>.delayed(Duration.zero);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      var bytes = file.bytes;
      final path = file.path;
      if ((bytes == null || bytes.isEmpty) && path != null && path.isNotEmpty) {
        bytes = await File(path).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        throw SunatLogoException(
          l(
            'No se pudo leer la imagen. Usa PNG o JPG.',
            'Could not read the image. Use PNG or JPG.',
          ),
        );
      }
      final prepared = SunatLogo.preparePng(bytes);
      if (!mounted) return;
      setState(() {
        _logo = prepared;
        _showLogo = true;
      });
      unawaited(_persist());
    } on SunatLogoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l('No se pudo guardar el logo.', 'Could not save the logo.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingLogo = false);
    }
  }

  void _clearLogo() {
    setState(() {
      _logo = null;
      _showLogo = false;
    });
    unawaited(_persist());
  }

  void _recalcTotals({bool force = false}) {
    if (_totalsManual && !force) return;
    final calc = CustomTicketTotals.fromLines(_lines);
    _subtotalCtrl.text = CustomTicketMoney.format(calc.subtotal);
    _taxCtrl.text = CustomTicketMoney.format(calc.igv);
    _totalCtrl.text = CustomTicketMoney.format(calc.total);
    _totalsManual = false;
    if (mounted) setState(() {});
  }

  void _onTotalsManualEdit() {
    if (_totalsManual) return;
    setState(() => _totalsManual = true);
  }

  CustomTicketLine _withAutoAmount(CustomTicketLine line) {
    if (!line.isItem) return line;
    final pu = CustomTicketMoney.parse(line.unitPrice);
    if (pu == null) return line;
    final q = CustomTicketMoney.parse(line.qty) ?? 1.0;
    return line.copyWith(amount: CustomTicketMoney.format(q * pu));
  }

  void _addLine(CustomTicketLineType type) {
    setState(() {
      _lines = [
        ..._lines,
        CustomTicketLine(
          type: type,
          qty: type == CustomTicketLineType.item ? '1' : '',
        ),
      ];
    });
    _recalcTotals();
  }

  void _removeLine(int index) {
    setState(() {
      _lines = List.of(_lines)..removeAt(index);
    });
    _recalcTotals();
  }

  void _updateLine(int index, CustomTicketLine line, {bool recomputeAmount = false}) {
    final next = recomputeAmount ? _withAutoAmount(line) : line;
    setState(() {
      _lines = List.of(_lines)..[index] = next;
    });
    _recalcTotals();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);

    if (_missing) {
      return Scaffold(
        appBar: AppBar(title: Text(l('Tickets propios', 'Custom tickets'))),
        body: Center(
          child: Text(l('Plantilla no encontrada.', 'Template not found.')),
        ),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_loading && _id.isNotEmpty) unawaited(_persist());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l('Editar ticket', 'Edit ticket')),
          actions: [
            TextButton(
              onPressed: _loading || _saving ? null : _preview,
              child: Text(l('Vista previa', 'Preview')),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : BoletaPage(
                bottomBar: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveAndClose,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l('Guardar', 'Save')),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      maxLength: CustomTicketTemplate.maxNameLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: l('Nombre de la plantilla', 'Template name'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l('Logo', 'Logo'),
                      style: theme.textTheme.titleMedium,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l('Mostrar logo', 'Show logo')),
                      value: _showLogo && _logo != null,
                      onChanged: _logo == null
                          ? null
                          : (v) {
                              setState(() => _showLogo = v);
                              unawaited(_persist());
                            },
                    ),
                    if (_logo != null) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.memory(
                            _logo!,
                            height: 96,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _savingLogo ? null : _pickLogo,
                          icon: _savingLogo
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.image_outlined),
                          label: Text(l('Elegir imagen', 'Choose image')),
                        ),
                        OutlinedButton.icon(
                          onPressed: _logo == null || _savingLogo ? null : _clearLogo,
                          icon: const Icon(Icons.hide_image_outlined),
                          label: Text(l('Quitar logo', 'Remove logo')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _titleCtrl,
                      maxLength: CustomTicketTemplate.maxTitleLength,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: l('Título', 'Title'),
                        helperText: l(
                          'Se imprime centrado y en negrita.',
                          'Printed centered and bold.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l('Líneas', 'Lines'),
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        PopupMenuButton<CustomTicketLineType>(
                          tooltip: l('Agregar línea', 'Add line'),
                          onSelected: _addLine,
                          itemBuilder: (ctx) {
                            final loc = L.of(ctx);
                            return [
                              PopupMenuItem(
                                value: CustomTicketLineType.text,
                                child: Text(loc('Línea libre', 'Free line')),
                              ),
                              PopupMenuItem(
                                value: CustomTicketLineType.item,
                                child: Text(loc('Ítem', 'Item')),
                              ),
                            ];
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 20),
                                const SizedBox(width: 6),
                                Text(l('Agregar', 'Add')),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _lines.length; i++)
                      _LineEditor(
                        index: i,
                        line: _lines[i],
                        onChanged: (line, {bool recomputeAmount = false}) =>
                            _updateLine(i, line, recomputeAmount: recomputeAmount),
                        onRemove: () => _removeLine(i),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      l('Totales', 'Totals'),
                      style: theme.textTheme.titleMedium,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l('Mostrar totales', 'Show totals')),
                      value: _showTotals,
                      onChanged: (v) => setState(() => _showTotals = v),
                    ),
                    if (_showTotals) ...[
                      Text(
                        l(
                          'Montos de ítem sin IGV. Op. Gravada = suma; IGV = 18%; Total = Op. Gravada + IGV. Se recalcula al cambiar líneas (puedes editar a mano).',
                          'Line amounts exclude IGV. Op. Gravada = sum; IGV = 18%; Total = Op. Gravada + IGV. Recalculates when lines change (you can override).',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _recalcTotals(force: true),
                          icon: const Icon(Icons.calculate_outlined, size: 18),
                          label: Text(l('Recalcular', 'Recalculate')),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _currencyCtrl,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: l('Moneda', 'Currency'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _subtotalLabelCtrl,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: l('Etiqueta subtotal', 'Subtotal label'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _subtotalCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _onTotalsManualEdit(),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: l('Op. Gravada', 'Taxable ops'),
                          helperText: _totalsManual
                              ? l('Editado manualmente', 'Manually edited')
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _taxLabelCtrl,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: l('Etiqueta impuesto', 'Tax label'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _taxCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => _onTotalsManualEdit(),
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: l('IGV 18%', 'VAT 18%'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _totalLabelCtrl,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: l('Etiqueta total', 'Total label'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _totalCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => _onTotalsManualEdit(),
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: l('Total', 'Total'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      l('Códigos', 'Codes'),
                      style: theme.textTheme.titleMedium,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l('Código QR', 'QR code')),
                      value: _showQr,
                      onChanged: (v) => setState(() => _showQr = v),
                    ),
                    if (_showQr)
                      TextField(
                        controller: _qrCtrl,
                        maxLength: CustomTicketTemplate.maxCodeLength,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: l('Datos del QR', 'QR payload'),
                        ),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l('Código de barras', 'Barcode')),
                      subtitle: Text(
                        l(
                          'Code 128. Usa letras y números.',
                          'Code 128. Use letters and numbers.',
                        ),
                      ),
                      value: _showBarcode,
                      onChanged: (v) => setState(() => _showBarcode = v),
                    ),
                    if (_showBarcode)
                      TextField(
                        controller: _barcodeCtrl,
                        maxLength: CustomTicketTemplate.maxCodeLength,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: l('Datos del código', 'Barcode payload'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      l('Pie de ticket', 'Footer'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _footerCtrl,
                      maxLength: CustomTicketTemplate.maxFooterLength,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: l('Nota al pie', 'Footer note'),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

typedef _LineChanged = void Function(
  CustomTicketLine line, {
  bool recomputeAmount,
});

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.index,
    required this.line,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final CustomTicketLine line;
  final _LineChanged onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.isItem
                        ? l('Ítem ${index + 1}', 'Item ${index + 1}')
                        : l('Línea ${index + 1}', 'Line ${index + 1}'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: l('Eliminar', 'Delete'),
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (line.isItem) ...[
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: TextFormField(
                      initialValue: line.qty,
                      onChanged: (v) => onChanged(line.copyWith(qty: v), recomputeAmount: true),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: l('Cant.', 'Qty'),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: line.text,
                      onChanged: (v) => onChanged(line.copyWith(text: v)),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: l('Descripción', 'Description'),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('pu-$index-${line.unitPrice}'),
                      initialValue: line.unitPrice,
                      onChanged: (v) => onChanged(line.copyWith(unitPrice: v), recomputeAmount: true),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: l('P.U. (sin IGV)', 'Unit (ex-IGV)'),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('amt-$index-${line.amount}'),
                      initialValue: line.amount,
                      onChanged: (v) => onChanged(line.copyWith(amount: v)),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: l('Importe (sin IGV)', 'Amount (ex-IGV)'),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextFormField(
                initialValue: line.text,
                maxLines: 2,
                onChanged: (v) => onChanged(line.copyWith(text: v)),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: l('Texto', 'Text'),
                  isDense: true,
                ),
              ),
              Row(
                children: [
                  FilterChip(
                    label: Text(l('Negrita', 'Bold')),
                    selected: line.bold,
                    onSelected: (v) => onChanged(line.copyWith(bold: v)),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(l('Centrar', 'Center')),
                    selected: line.center,
                    onSelected: (v) => onChanged(line.copyWith(center: v)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}