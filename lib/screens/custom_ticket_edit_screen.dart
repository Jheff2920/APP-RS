import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_lang.dart';
import '../services/custom_ticket/custom_ticket.dart';
import '../services/custom_ticket/custom_ticket_store.dart';
import '../services/print_service.dart';
import '../services/printer_store.dart';
import '../services/sunat/sunat_logo.dart';
import '../theme.dart';
import '../widgets/boleta_page.dart';
import '../widgets/ui_kit.dart';
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
  final _companyNameCtrl = TextEditingController();
  final _rucCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
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
  var _includeIgv = true;
  var _showQr = false;
  var _showBarcode = false;
  Uint8List? _logo;
  List<CustomTicketLine> _lines = [];
  String _id = '';

  /// Si el usuario edita totales a mano, no pisar hasta que cambien líneas o pulse Recalcular.
  var _totalsManual = false;
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyNameCtrl.dispose();
    _rucCtrl.dispose();
    _addressCtrl.dispose();
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

  String _newLineId() => _uuid.v4();

  CustomTicketLine _ensureLineId(CustomTicketLine line) {
    if (line.id.isNotEmpty) return line;
    return line.copyWith(id: _newLineId());
  }

  List<CustomTicketLine> _ensureLineIds(List<CustomTicketLine> lines) =>
      [for (final line in lines) _ensureLineId(line)];

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
    _companyNameCtrl.text = t.companyName;
    _rucCtrl.text = t.ruc;
    _addressCtrl.text = t.address;
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
      _includeIgv = t.includeIgv;
      _showQr = t.showQr;
      _showBarcode = t.showBarcode;
      _logo = t.logoBytes;
      _lines = _ensureLineIds(List.of(t.lines));
      _loading = false;
    });
    final hasTotals = t.subtotal.trim().isNotEmpty ||
        t.tax.trim().isNotEmpty ||
        t.total.trim().isNotEmpty;
    if (!hasTotals) {
      _recalcTotals(force: true);
    } else if (!t.includeIgv) {
      // Sin IGV: solo TOTAL; no mostrar/guardar Op. Gravada ni IGV.
      _subtotalCtrl.text = '';
      _taxCtrl.text = '';
      _totalCtrl.text = CustomTicketMoney.formatRaw(t.total);
      _totalsManual = false;
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
      title: _companyNameCtrl.text,
      lines: List.of(_lines),
      showLogo: _showLogo,
      logoBytes: _logo,
      companyName: _companyNameCtrl.text,
      ruc: _rucCtrl.text,
      address: _addressCtrl.text,
      footer: _footerCtrl.text,
      showTotals: _showTotals,
      includeIgv: _includeIgv,
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
          content: Text(
              l('No se pudo guardar el logo.', 'Could not save the logo.')),
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
    final calc = CustomTicketTotals.fromLines(
      _lines,
      includeIgv: _includeIgv,
    );
    if (_includeIgv) {
      _subtotalCtrl.text = CustomTicketMoney.format(calc.subtotal);
      _taxCtrl.text = CustomTicketMoney.format(calc.igv);
    } else {
      _subtotalCtrl.text = '';
      _taxCtrl.text = '';
    }
    _totalCtrl.text = CustomTicketMoney.format(calc.total);
    _totalsManual = false;
    if (mounted) setState(() {});
  }

  void _setIncludeIgv(bool value) {
    setState(() => _includeIgv = value);
    _recalcTotals(force: true);
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
          id: _newLineId(),
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

  void _updateLine(int index, CustomTicketLine line,
      {bool recomputeAmount = false}) {
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
            if (useCompactActions(context))
              IconButton(
                tooltip: l('Vista previa', 'Preview'),
                onPressed: _loading || _saving ? null : _preview,
                icon: const Icon(Icons.visibility_outlined),
              )
            else
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _loading || _saving ? null : _preview,
                icon: const Icon(Icons.visibility_outlined, size: 20),
                label: Text(l('Vista previa', 'Preview')),
              ),
            const SizedBox(width: 4),
          ],
        ),
        // En el Scaffold para que los avisos salgan encima de «Guardar».
        bottomNavigationBar: _loading
            ? null
            : BottomActions(
                children: [
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveAndClose,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l('Guardar', 'Save')),
                  ),
                ],
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : BoletaPage(
                maxContentWidth: 640,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    SectionLabel(l('Plantilla', 'Template')),
                    Card(
                      child: SectionBody(
                        children: [
                          TextField(
                            key: const ValueKey('template-name'),
                            controller: _nameCtrl,
                            maxLength: CustomTicketTemplate.maxNameLength,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText:
                                  l('Nombre de la plantilla', 'Template name'),
                              helperText: l(
                                'Solo para ti, no se imprime.',
                                'Only for you, not printed.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SectionLabel(l('Logo', 'Logo')),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchRow(
                            title: l('Mostrar logo', 'Show logo'),
                            subtitle: _logo == null
                                ? l('Primero elige una imagen.', 'Pick an image first.')
                                : null,
                            value: _showLogo && _logo != null,
                            onChanged: _logo == null
                                ? null
                                : (v) {
                                    setState(() => _showLogo = v);
                                    unawaited(_persist());
                                  },
                          ),
                          const Divider(height: 1),
                          SectionBody(
                            children: [
                              if (_logo != null) ...[
                                Container(
                                  height: 110,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.line),
                                  ),
                                  child: Image.memory(
                                    _logo!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      onPressed:
                                          _savingLogo ? null : _pickLogo,
                                      icon: _savingLogo
                                          ? const ButtonSpinner()
                                          : const Icon(Icons.image_outlined),
                                      label: Text(
                                        l('Elegir imagen', 'Choose image'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _logo == null || _savingLogo
                                          ? null
                                          : _clearLogo,
                                      icon: const Icon(
                                        Icons.hide_image_outlined,
                                      ),
                                      label: Text(l('Quitar', 'Remove')),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SectionLabel(l('Datos de la tienda', 'Store details')),
                    Card(
                      child: SectionBody(
                        children: [
                    TextField(
                      key: const ValueKey('company-name'),
                      controller: _companyNameCtrl,
                      maxLength: CustomTicketTemplate.maxCompanyNameLength,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: l('Nombre de la tienda / empresa',
                            'Store / company name'),
                        helperText: l(
                          'Se imprime centrado bajo el logo.',
                          'Printed centered under the logo.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _rucCtrl,
                      maxLength: CustomTicketTemplate.maxRucLength,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l('RUC', 'Tax ID (RUC)'),
                        helperText: l(
                          'Se imprime como RUC: ... centrado.',
                          'Printed as RUC: ... centered.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressCtrl,
                      maxLength: CustomTicketTemplate.maxAddressLength,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText:
                            l('Dirección / ubicación', 'Address / location'),
                        alignLabelWithHint: true,
                        helperText: l(
                          'Se imprime centrado bajo el RUC.',
                          'Printed centered under the RUC.',
                        ),
                      ),
                    ),
                        ],
                      ),
                    ),
                    SectionLabel(
                      l('Contenido', 'Content'),
                      padding: const EdgeInsets.fromLTRB(4, 14, 0, 4),
                      trailing: PopupMenuButton<CustomTicketLineType>(
                        tooltip: l('Agregar línea', 'Add line'),
                        onSelected: _addLine,
                        itemBuilder: (ctx) {
                          final loc = L.of(ctx);
                          return [
                            PopupMenuItem(
                              value: CustomTicketLineType.item,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.shopping_bag_outlined),
                                title: Text(loc('Producto', 'Product')),
                                subtitle: Text(
                                  loc('Cantidad, precio e importe', 'Qty, price and amount'),
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: CustomTicketLineType.text,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.short_text_rounded),
                                title: Text(loc('Texto libre', 'Free text')),
                                subtitle: Text(
                                  loc('Un mensaje o separador', 'A message or divider'),
                                ),
                              ),
                            ),
                          ];
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l('Agregar línea', 'Add line'),
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_lines.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InfoNote(
                          text: l(
                            'Agrega productos o texto con "Agregar línea".',
                            'Add products or text with "Add line".',
                          ),
                        ),
                      ),
                    for (var i = 0; i < _lines.length; i++)
                      _LineEditor(
                        key: ValueKey(_lines[i].id),
                        index: i,
                        line: _lines[i],
                        includeIgv: _includeIgv,
                        onChanged: (line, {bool recomputeAmount = false}) =>
                            _updateLine(i, line,
                                recomputeAmount: recomputeAmount),
                        onRemove: () => _removeLine(i),
                      ),
                    SectionLabel(l('Totales', 'Totals')),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                    SwitchRow(
                      title: l('Mostrar totales', 'Show totals'),
                      value: _showTotals,
                      onChanged: (v) => setState(() => _showTotals = v),
                    ),
                    if (_showTotals) ...[
                      const Divider(height: 1),
                      SwitchRow(
                        title: l('Incluir IGV', 'Include IGV'),
                        subtitle: l(
                          'Desactiva si tu negocio no cobra IGV.',
                          'Turn off if your business does not charge IGV.',
                        ),
                        value: _includeIgv,
                        onChanged: _setIncludeIgv,
                      ),
                      const Divider(height: 1),
                      SectionBody(
                        children: [
                      Text(
                        _includeIgv
                            ? l(
                                'Montos de ítem sin IGV. Op. Gravada = suma; IGV = 18%; Total = Op. Gravada + IGV. Se recalcula al cambiar líneas (puedes editar a mano).',
                                'Line amounts exclude IGV. Op. Gravada = sum; IGV = 18%; Total = Op. Gravada + IGV. Recalculates when lines change (you can override).',
                              )
                            : l(
                                'Sin IGV. TOTAL = suma de importes de línea. Se recalcula al cambiar líneas (puedes editar a mano).',
                                'No IGV. TOTAL = sum of line amounts. Recalculates when lines change (you can override).',
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
                      if (_includeIgv) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _currencyCtrl,
                                decoration: InputDecoration(
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
                                  labelText:
                                      l('Etiqueta subtotal', 'Subtotal label'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _subtotalCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => _onTotalsManualEdit(),
                          decoration: InputDecoration(
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
                                  labelText:
                                      l('Etiqueta impuesto', 'Tax label'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _taxCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (_) => _onTotalsManualEdit(),
                                decoration: InputDecoration(
                                  labelText: l('IGV 18%', 'VAT 18%'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        TextField(
                          controller: _currencyCtrl,
                          decoration: InputDecoration(
                            labelText: l('Moneda', 'Currency'),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _totalLabelCtrl,
                              decoration: InputDecoration(
                                labelText: l('Etiqueta total', 'Total label'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _totalCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (_) => _onTotalsManualEdit(),
                              decoration: InputDecoration(
                                labelText: l('Total', 'Total'),
                                helperText: !_includeIgv && _totalsManual
                                    ? l('Editado manualmente',
                                        'Manually edited')
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                        ],
                      ),
                    ],
                        ],
                      ),
                    ),
                    SectionLabel(l('Códigos', 'Codes')),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchRow(
                            title: l('Código QR', 'QR code'),
                            value: _showQr,
                            onChanged: (v) => setState(() => _showQr = v),
                          ),
                          if (_showQr)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                              child: TextField(
                                controller: _qrCtrl,
                                maxLength: CustomTicketTemplate.maxCodeLength,
                                decoration: InputDecoration(
                                  labelText: l('Datos del QR', 'QR content'),
                                  hintText: l(
                                    'Ej.: un enlace o tu número de Yape',
                                    'E.g. a link or a phone number',
                                  ),
                                ),
                              ),
                            ),
                          const Divider(height: 1),
                          SwitchRow(
                            title: l('Código de barras', 'Barcode'),
                            subtitle: l(
                              'Code 128. Usa letras y números.',
                              'Code 128. Use letters and numbers.',
                            ),
                            value: _showBarcode,
                            onChanged: (v) => setState(() => _showBarcode = v),
                          ),
                          if (_showBarcode)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                              child: TextField(
                                controller: _barcodeCtrl,
                                maxLength: CustomTicketTemplate.maxCodeLength,
                                decoration: InputDecoration(
                                  labelText:
                                      l('Datos del código', 'Barcode content'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SectionLabel(l('Pie de ticket', 'Footer')),
                    Card(
                      child: SectionBody(
                        children: [
                          TextField(
                            controller: _footerCtrl,
                            maxLength: CustomTicketTemplate.maxFooterLength,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: l('Nota al pie', 'Footer note'),
                              hintText: l(
                                'Ej.: Gracias por su compra',
                                'E.g. Thank you for your purchase',
                              ),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
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

class _LineEditor extends StatefulWidget {
  const _LineEditor({
    super.key,
    required this.index,
    required this.line,
    required this.includeIgv,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final CustomTicketLine line;
  final bool includeIgv;
  final _LineChanged onChanged;
  final VoidCallback onRemove;

  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _textCtrl;
  late final TextEditingController _unitPriceCtrl;
  late final TextEditingController _amountCtrl;
  late final FocusNode _qtyFocus;
  late final FocusNode _textFocus;
  late final FocusNode _unitPriceFocus;
  late final FocusNode _amountFocus;

  /// True while applying programmatic controller updates (avoids feedback loops).
  var _syncing = false;

  CustomTicketLine get line => widget.line;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: line.qty);
    _textCtrl = TextEditingController(text: line.text);
    _unitPriceCtrl = TextEditingController(text: line.unitPrice);
    _amountCtrl = TextEditingController(text: line.amount);
    _qtyFocus = FocusNode();
    _textFocus = FocusNode();
    _unitPriceFocus = FocusNode();
    _amountFocus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _LineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep typed text; only pull parent-driven changes (e.g. auto importe) when
    // that field is not focused, so setState/totals never steal caret.
    _syncIfUnfocused(_qtyCtrl, _qtyFocus, line.qty);
    _syncIfUnfocused(_textCtrl, _textFocus, line.text);
    _syncIfUnfocused(_unitPriceCtrl, _unitPriceFocus, line.unitPrice);
    _syncIfUnfocused(_amountCtrl, _amountFocus, line.amount);
  }

  void _syncIfUnfocused(
    TextEditingController ctrl,
    FocusNode focus,
    String value,
  ) {
    if (focus.hasFocus) return;
    if (ctrl.text == value) return;
    _syncing = true;
    ctrl.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _syncing = false;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _textCtrl.dispose();
    _unitPriceCtrl.dispose();
    _amountCtrl.dispose();
    _qtyFocus.dispose();
    _textFocus.dispose();
    _unitPriceFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  CustomTicketLine _snapshot({
    String? qty,
    String? text,
    String? unitPrice,
    String? amount,
    bool? bold,
    bool? center,
  }) {
    return line.copyWith(
      qty: qty ?? _qtyCtrl.text,
      text: text ?? _textCtrl.text,
      unitPrice: unitPrice ?? _unitPriceCtrl.text,
      amount: amount ?? _amountCtrl.text,
      bold: bold,
      center: center,
    );
  }

  void _emit({bool recomputeAmount = false}) {
    if (_syncing) return;
    widget.onChanged(_snapshot(), recomputeAmount: recomputeAmount);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final id = line.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  line.isItem
                      ? Icons.shopping_bag_outlined
                      : Icons.short_text_rounded,
                  size: 18,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.isItem
                        ? l('Producto ${widget.index + 1}',
                            'Product ${widget.index + 1}')
                        : l('Texto ${widget.index + 1}',
                            'Text ${widget.index + 1}'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.inkSoft),
                  ),
                ),
                IconButton(
                  tooltip: l('Eliminar', 'Delete'),
                  onPressed: widget.onRemove,
                  color: AppColors.inkSoft,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (line.isItem) ...[
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: TextField(
                      key: ValueKey('qty-$id'),
                      controller: _qtyCtrl,
                      focusNode: _qtyFocus,
                      onChanged: (_) => _emit(recomputeAmount: true),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l('Cant.', 'Qty'),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: ValueKey('desc-$id'),
                      controller: _textCtrl,
                      focusNode: _textFocus,
                      onChanged: (_) => _emit(),
                      decoration: InputDecoration(
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
                    child: TextField(
                      key: ValueKey('pu-$id'),
                      controller: _unitPriceCtrl,
                      focusNode: _unitPriceFocus,
                      onChanged: (_) => _emit(recomputeAmount: true),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: widget.includeIgv
                            ? l('P.U. (sin IGV)', 'Unit (ex-IGV)')
                            : l('P.U.', 'Unit'),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: ValueKey('amt-$id'),
                      controller: _amountCtrl,
                      focusNode: _amountFocus,
                      onChanged: (_) => _emit(),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: widget.includeIgv
                            ? l('Importe (sin IGV)', 'Amount (ex-IGV)')
                            : l('Importe', 'Amount'),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextField(
                key: ValueKey('text-$id'),
                controller: _textCtrl,
                focusNode: _textFocus,
                maxLines: 2,
                onChanged: (_) => _emit(),
                decoration: InputDecoration(
                  labelText: l('Texto', 'Text'),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilterChip(
                    label: Text(l('Negrita', 'Bold')),
                    selected: line.bold,
                    onSelected: (v) => widget.onChanged(_snapshot(bold: v)),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(l('Centrar', 'Center')),
                    selected: line.center,
                    onSelected: (v) => widget.onChanged(_snapshot(center: v)),
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
