import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../services/sunat/sunat_logo.dart';
import '../services/sunat/sunat_print_settings.dart';
import '../widgets/boleta_page.dart';

class SunatPrintSettingsScreen extends StatefulWidget {
  const SunatPrintSettingsScreen({super.key, this.store});

  final SunatPrintStore? store;

  @override
  State<SunatPrintSettingsScreen> createState() =>
      _SunatPrintSettingsScreenState();
}

class _SunatPrintSettingsScreenState extends State<SunatPrintSettingsScreen> {
  late final SunatPrintStore _store = widget.store ?? SunatPrintStore();
  final _noteController = TextEditingController();
  var _loading = true;
  var _savingLogo = false;
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
    if (!mounted) return;
    _noteController.text = settings.footerNote;
    setState(() {
      _format = settings.format;
      _showQr = settings.showQr;
      _showLegend = settings.showLegend;
      _logo = logo;
      _loading = false;
    });
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
    await _store.save(_current());
  }

  Future<void> _saveAndClose() async {
    await _persist();
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
    await _store.clearLogo();
    if (!mounted) return;
    setState(() => _logo = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_loading) unawaited(_persist());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l('Ticket SUNAT', 'SUNAT ticket'))),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : BoletaPage(
                bottomBar: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _savingLogo ? null : _saveAndClose,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l('Guardar', 'Save')),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Text(
                      l('Formato', 'Format'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<SunatTicketFormat>(
                      expandedInsets: EdgeInsets.zero,
                      showSelectedIcon: false,
                      segments: [
                        for (final format in SunatTicketFormat.values)
                          ButtonSegment(
                            value: format,
                            label: Text(format.label(l.english)),
                          ),
                      ],
                      selected: {_format},
                      onSelectionChanged: (selected) {
                        if (selected.isEmpty) return;
                        setState(() => _format = selected.first);
                        unawaited(_persist());
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _format.hint(l.english),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l('Logo de la empresa', 'Company logo'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l(
                        'Se imprime centrado, arriba del ticket. Si no eliges '
                        'imagen, el comprobante sale sin logo.',
                        'Printed centered at the top of the ticket. If you do '
                        'not pick an image, the receipt has no logo.',
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_logo != null) ...[
                      Semantics(
                        label: l('Logo de la empresa', 'Company logo'),
                        image: true,
                        child: DecoratedBox(
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
                          onPressed: _logo == null || _savingLogo
                              ? null
                              : _clearLogo,
                          icon: const Icon(Icons.hide_image_outlined),
                          label: Text(l('Quitar logo', 'Remove logo')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l('Nota al pie', 'Footer note'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l(
                        'Texto por defecto al imprimir un XML o ZIP SUNAT. '
                        'En la pantalla de impresión puedes cambiarlo para ese trabajo.',
                        'Default text when printing a SUNAT XML or ZIP. '
                        'On the print screen you can change it for that job.',
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      maxLength: SunatPrintSettings.maxNoteLength,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: l('Nota', 'Note'),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l('Contenido', 'Content'),
                      style: theme.textTheme.titleMedium,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l('Código QR', 'QR code')),
                      subtitle: Text(
                        l(
                          'Para consultar el comprobante en SUNAT.',
                          'To look up the receipt on SUNAT.',
                        ),
                      ),
                      value: _showQr,
                      onChanged: (value) {
                        setState(() => _showQr = value);
                        unawaited(_persist());
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l('Monto en letras', 'Amount in words')),
                      subtitle: Text(
                        l(
                          'La leyenda del XML, si viene.',
                          'The XML legend, when present.',
                        ),
                      ),
                      value: _showLegend,
                      onChanged: (value) {
                        setState(() => _showLegend = value);
                        unawaited(_persist());
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
