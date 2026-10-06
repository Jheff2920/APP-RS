import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../services/printer_store.dart';
import '../services/redpos/redpos_license.dart';
import '../services/sunat/sunat_logo.dart';
import '../services/sunat/sunat_print_settings.dart';
import '../theme.dart';
import '../widgets/redpos_paid_gate.dart';
import '../widgets/ui_kit.dart';

class SunatPrintSettingsScreen extends StatefulWidget {
  const SunatPrintSettingsScreen({super.key, this.store, this.printerStore});

  final SunatPrintStore? store;
  final PrinterStore? printerStore;

  @override
  State<SunatPrintSettingsScreen> createState() =>
      _SunatPrintSettingsScreenState();
}

class _SunatPrintSettingsScreenState extends State<SunatPrintSettingsScreen> {
  late final SunatPrintStore _store = widget.store ?? SunatPrintStore();
  late final PrinterStore _printerStore =
      widget.printerStore ?? PrinterStore();
  final _noteController = TextEditingController();
  var _loading = true;
  var _savingLogo = false;
  var _unlocked = false;
  var _format = SunatTicketFormat.claro;
  var _showQr = true;
  var _showLegend = true;
  Uint8List? _logo;

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
    final settings = await _store.load();
    final logo = await _store.loadLogoBytes();
    final unlocked =
        await RedPosLicenseStore.instance.isAdsFree(reloadDisk: false);
    if (!mounted) return;
    _noteController.text = settings.footerNote;
    setState(() {
      _format = settings.format;
      _showQr = settings.showQr;
      _showLegend = settings.showLegend;
      _logo = logo;
      _unlocked = unlocked;
      _loading = false;
    });
  }

  Future<void> _refreshUnlock() async {
    final unlocked = await RedPosLicenseStore.instance.isAdsFree();
    if (!mounted) return;
    setState(() => _unlocked = unlocked);
  }

  SunatPrintSettings _current() {
    return SunatPrintSettings(
      format: _format,
      footerNote: _noteController.text,
      showQr: _showQr,
      showLegend: _showLegend,
    );
  }

  Future<void> _persist() async {
    // El formato es gratis; los extras de pago solo se guardan con pase.
    if (_unlocked) {
      await _store.save(_current());
      return;
    }
    final saved = await _store.load();
    await _store.save(
      saved.copyWith(format: _format),
    );
  }

  Future<void> _saveAndClose() async {
    await _persist();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _pickLogo() async {
    if (!_unlocked) return;
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
      await _store.saveLogo(bytes);
      final stored = await _store.loadLogoBytes();
      if (!mounted) return;
      setState(() => _logo = stored);
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
            l(
              'No se pudo guardar el logo.',
              'Could not save the logo.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingLogo = false);
    }
  }

  Future<void> _clearLogo() async {
    if (!_unlocked) return;
    await _store.clearLogo();
    if (!mounted) return;
    setState(() => _logo = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tt = Theme.of(context).textTheme;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_loading) unawaited(_persist());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l('Ticket SUNAT', 'SUNAT ticket'))),
        bottomNavigationBar: _loading
            ? null
            : BottomActions(
                children: [
                  FilledButton.icon(
                    onPressed: _savingLogo ? null : _saveAndClose,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l('Guardar', 'Save')),
                  ),
                ],
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : PageList(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                    child: Text(
                      l(
                        'Así se imprimen las boletas y facturas que abres desde '
                            'un XML o ZIP de SUNAT.',
                        'This is how receipts opened from a SUNAT XML or ZIP '
                            'are printed.',
                      ),
                      style: tt.bodyMedium?.copyWith(color: AppColors.inkSoft),
                    ),
                  ),
                  SectionLabel(l('Formato', 'Format')),
                  SectionGroup(
                    children: [
                      for (final format in SunatTicketFormat.values)
                        OptionRow(
                          title: format.label(l.english),
                          subtitle: format.hint(l.english),
                          selected: _format == format,
                          onTap: () {
                            setState(() => _format = format);
                            unawaited(_persist());
                          },
                        ),
                    ],
                  ),
                  if (_unlocked) ..._paidSections(l, tt) else ..._lockedSections(l),
                ],
              ),
      ),
    );
  }

  List<Widget> _paidSections(L l, TextTheme tt) {
    return [
      SectionLabel(l('Logo de la empresa', 'Company logo')),
      Card(
        child: SectionBody(
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              child: _logo != null
                  ? Semantics(
                      label: l('Logo de la empresa', 'Company logo'),
                      image: true,
                      child: Image.memory(_logo!, fit: BoxFit.contain),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          color: AppColors.inkSoft,
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l('Sin logo', 'No logo'),
                          style: tt.bodySmall
                              ?.copyWith(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              l(
                'Se imprime centrado arriba del ticket.',
                'Printed centered at the top of the ticket.',
              ),
              style: tt.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _savingLogo ? null : _pickLogo,
                    icon: _savingLogo
                        ? const ButtonSpinner()
                        : const Icon(Icons.image_outlined),
                    label: Text(l('Elegir imagen', 'Choose image')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _logo == null || _savingLogo ? null : _clearLogo,
                    icon: const Icon(Icons.hide_image_outlined),
                    label: Text(l('Quitar logo', 'Remove logo')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      SectionLabel(l('Nota al pie', 'Footer note')),
      Card(
        child: SectionBody(
          children: [
            TextField(
              controller: _noteController,
              maxLength: SunatPrintSettings.maxNoteLength,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l('Ej.: Gracias por su compra', 'E.g. Thank you!'),
                helperText: l(
                  'Se usa en todos los tickets. Al imprimir puedes '
                      'cambiarla solo para ese ticket.',
                  'Used on every ticket. When printing you can change it '
                      'for that ticket only.',
                ),
                helperMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      SectionLabel(l('Contenido', 'Content')),
      SectionGroup(
        children: [
          SwitchRow(
            title: l('Código QR', 'QR code'),
            subtitle: l(
              'Para consultar el comprobante en SUNAT.',
              'To look up the receipt on SUNAT.',
            ),
            value: _showQr,
            onChanged: (value) {
              setState(() => _showQr = value);
              unawaited(_persist());
            },
          ),
          SwitchRow(
            title: l('Monto en letras', 'Amount in words'),
            subtitle: l(
              'La leyenda del XML, si viene.',
              'The XML legend, when present.',
            ),
            value: _showLegend,
            onChanged: (value) {
              setState(() => _showLegend = value);
              unawaited(_persist());
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _lockedSections(L l) {
    Widget row(String title, String subtitle) => NavRow(
          icon: Icons.lock_outline,
          color: AppColors.inkSoft,
          title: title,
          subtitle: subtitle,
        );
    return [
      SectionLabel(l('Con desbloqueo', 'With unlock')),
      SectionGroup(
        dividerIndent: 68,
        children: [
          row(
            l('Logo de la empresa', 'Company logo'),
            l('Tu logo arriba de cada ticket', 'Your logo on top of each ticket'),
          ),
          row(
            l('Nota al pie', 'Footer note'),
            l('Un mensaje propio al final', 'Your own message at the bottom'),
          ),
          row(
            l('Código QR y monto en letras', 'QR code and amount in words'),
            l(
              'Mostrar u ocultar. Sin pase, el QR se imprime igual.',
              'Show or hide. Without a pass, the QR still prints.',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      RedPosPaidGateBanner(
        store: _printerStore,
        onUnlocked: () => unawaited(_refreshUnlock()),
        compact: true,
      ),
    ];
  }
}