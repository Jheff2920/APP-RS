import 'package:flutter/material.dart';
import '../models/saved_printer.dart';
import '../services/printer_store.dart';
import 'ui_kit.dart';

class LogicalPrinterSettings extends StatelessWidget {
  const LogicalPrinterSettings(
      {super.key,
      required this.printerId,
      required this.kind,
      required this.protocol,
      required this.profiles,
      required this.defaultProfileId,
      required this.onKindChanged,
      required this.onProtocolChanged,
      required this.onProfilesChanged,
      required this.onDefaultChanged});

  final String printerId, defaultProfileId;
  final PrinterKind kind;
  final PrinterProtocol protocol;
  final List<PaperProfile> profiles;
  final ValueChanged<PrinterKind> onKindChanged;
  final ValueChanged<PrinterProtocol> onProtocolChanged;
  final ValueChanged<List<PaperProfile>> onProfilesChanged;
  final ValueChanged<String> onDefaultChanged;

  Future<void> _edit(BuildContext context, PaperProfile? profile) async {
    final result = await showDialog<PaperProfile>(
        context: context,
        builder: (_) => _PaperProfileDialog(
            profile: profile,
            printerId: printerId,
            newId: PrinterStore().newId()));
    if (result == null) return;
    onProfilesChanged([
      ...profiles.where((p) => p.paperProfileId != result.paperProfileId),
      result
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = profiles.where((p) => p.enabled).toList();
    final defaultId = enabled.any((p) => p.paperProfileId == defaultProfileId)
        ? defaultProfileId
        : enabled.firstOrNull?.paperProfileId;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionLabel('Uso de esta impresora'),
      Card(
          child: SectionBody(children: [
        SegmentedButton<PrinterKind>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: PrinterKind.receipt, label: Text('Recibos')),
              ButtonSegment(value: PrinterKind.label, label: Text('Etiquetas'))
            ],
            selected: {kind},
            onSelectionChanged: (s) => onKindChanged(s.first)),
        const SizedBox(height: 12),
        Text(kind == PrinterKind.receipt
            ? 'Android mostrará únicamente los tamaños de recibos habilitados.'
            : 'Android mostrará esta impresora por separado, con sus tamaños de etiquetas.'),
        if (kind == PrinterKind.label) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<PrinterProtocol>(
              key: ValueKey(protocol),
              initialValue: protocol,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Lenguaje de la impresora'),
              items: const [
                DropdownMenuItem(
                    value: PrinterProtocol.escpos, child: Text('ESC/POS')),
                DropdownMenuItem(
                    value: PrinterProtocol.tspl, child: Text('TSPL'))
              ],
              onChanged: (v) {
                if (v != null) onProtocolChanged(v);
              }),
          const SizedBox(height: 8),
          Text(protocol == PrinterProtocol.escpos
              ? 'ESC/POS avanza por distancia. El GAP suma separación; no activa un sensor de etiquetas.'
              : 'TSPL configura el tamaño y el GAP. Úsalo si tu impresora admite este lenguaje.'),
        ],
      ])),
      const SectionLabel('Tamaños disponibles en Android'),
      Card(
          child: Column(children: [
        for (final p in profiles) ...[
          SwitchListTile(
              title: Text(p.name),
              subtitle: kind == PrinterKind.label
                  ? Text('${p.widthMm} × ${p.heightMm} mm · GAP ${p.gapMm} mm')
                  : null,
              value: p.enabled,
              onChanged: p.enabled && enabled.length == 1
                  ? null
                  : (value) {
                      onProfilesChanged(profiles
                          .map((old) => old.paperProfileId == p.paperProfileId
                              ? PaperProfile.fromJson(
                                  {...old.toJson(), 'enabled': value})
                              : old)
                          .toList());
                    }),
          if (kind == PrinterKind.label)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(spacing: 8, children: [
                  TextButton.icon(
                      onPressed: () => _edit(context, p),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar tamaño')),
                  TextButton.icon(
                      onPressed: profiles.length == 1 ||
                              (p.enabled && enabled.length == 1)
                          ? null
                          : () => onProfilesChanged(profiles
                              .where(
                                  (e) => e.paperProfileId != p.paperProfileId)
                              .toList()),
                      style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar')),
                ])),
        ],
        if (kind == PrinterKind.label)
          TextButton.icon(
              onPressed: () => _edit(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Agregar tamaño de etiqueta')),
        if (enabled.isNotEmpty)
          Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                  key: ValueKey('$printerId-$defaultId-${enabled.length}'),
                  initialValue: defaultId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Tamaño predeterminado'),
                  items: [
                    for (final p in enabled)
                      DropdownMenuItem(
                          value: p.paperProfileId,
                          child: Text(p.name, overflow: TextOverflow.ellipsis))
                  ],
                  onChanged: (v) {
                    if (v != null) onDefaultChanged(v);
                  })),
      ])),
    ]);
  }
}

class _PaperProfileDialog extends StatefulWidget {
  const _PaperProfileDialog(
      {required this.profile, required this.printerId, required this.newId});
  final PaperProfile? profile;
  final String printerId, newId;
  @override
  State<_PaperProfileDialog> createState() => _PaperProfileDialogState();
}

class _PaperProfileDialogState extends State<_PaperProfileDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  String? _error;
  static const _labels = {
    'name': 'Nombre del tamaño',
    'widthMm': 'Ancho (mm)',
    'heightMm': 'Alto (mm)',
    'gapMm': 'Separación GAP (mm)',
    'leftMm': 'Margen izquierdo (mm)',
    'rightMm': 'Margen derecho (mm)',
    'topMm': 'Margen superior (mm)',
    'bottomMm': 'Margen inferior (mm)',
    'offsetXmm': 'Desplazamiento horizontal (mm)',
    'offsetYmm': 'Desplazamiento vertical (mm)',
    'scalePercent': 'Escala de calibración (%)'
  };
  @override
  void initState() {
    super.initState();
    final data = (widget.profile ??
            PaperProfile(
                paperProfileId: widget.newId,
                logicalPrinterId: widget.printerId,
                name: '',
                widthMm: 50,
                heightMm: 25))
        .toJson();
    _fields = {
      for (final key in _labels.keys)
        key: TextEditingController(text: '${data[key]}')
    };
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final data = <String, dynamic>{
      'paperProfileId': widget.profile?.paperProfileId ?? widget.newId,
      'logicalPrinterId': widget.printerId,
      'enabled': widget.profile?.enabled ?? true
    };
    for (final key in _labels.keys) {
      data[key] = key == 'name'
          ? _fields[key]!.text.trim()
          : double.parse(_fields[key]!.text.trim().replaceAll(',', '.'));
    }
    final profile = PaperProfile.fromJson(data);
    if (profile.validationError != null) {
      setState(() => _error = profile.validationError);
      return;
    }
    Navigator.pop(context, profile);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          scrollable: true,
          title:
              Text(widget.profile == null ? 'Agregar tamaño' : 'Editar tamaño'),
          content: SizedBox(
              width: 440,
              child: Form(
                  key: _form,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final entry in _labels.entries)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextFormField(
                                  controller: _fields[entry.key],
                                  decoration:
                                      InputDecoration(labelText: entry.value),
                                  keyboardType: entry.key == 'name'
                                      ? TextInputType.text
                                      : const TextInputType.numberWithOptions(
                                          decimal: true, signed: true),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Completa este campo.';
                                    }
                                    if (entry.key != 'name' &&
                                        !(double.tryParse(
                                                    v.replaceAll(',', '.'))
                                                ?.isFinite ??
                                            false)) {
                                      return 'Escribe una medida válida.';
                                    }
                                    return null;
                                  })),
                        if (_error != null)
                          Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                      ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(onPressed: _save, child: const Text('Guardar tamaño'))
          ]);
}
