import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/saved_printer.dart';
import '../services/printer_store.dart';
import 'ui_kit.dart';

/// Content rotation (clockwise degrees) as shown to the user.
const orientationNames = {
  0: 'Vertical',
  90: 'Horizontal',
  180: 'Vertical 180°',
  270: 'Horizontal 180°'
};

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
    // Reemplazar en su lugar: si no hay predeterminado explícito, manda el primero.
    final i =
        profiles.indexWhere((p) => p.paperProfileId == result.paperProfileId);
    onProfilesChanged(
        i < 0 ? [...profiles, result] : ([...profiles]..[i] = result));
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
            ? 'Los tamaños de recibo ya vienen configurados.'
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
      // Receipt sizes are fixed internally; only labels are configured here.
      if (kind == PrinterKind.label) ...[
        const SectionLabel('Tamaños de etiqueta'),
        if (profiles.isEmpty)
          const InfoNote(
              icon: Icons.label_outline,
              text:
                  'Aún no hay tamaños. Agrega el tamaño de tus etiquetas para poder imprimir.')
        else
          // One block per size, with dividers, so each button sits with its size.
          SectionGroup(children: [
            for (final p in profiles)
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SwitchListTile(
                    title: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${p.widthMm} × ${p.heightMm} mm · GAP ${p.gapMm} mm · '
                        '${orientationNames[p.rotation] ?? orientationNames[0]}'
                        '${p.darkness > 0 ? ' · Oscuridad ${p.darkness.clamp(0, 15)}' : ''}'
                        '${p.thicken ? ' · Trazo grueso' : ''}'),
                    value: p.enabled,
                    onChanged: p.enabled && enabled.length == 1
                        ? null
                        : (value) {
                            onProfilesChanged(profiles
                                .map((old) =>
                                    old.paperProfileId == p.paperProfileId
                                        ? PaperProfile.fromJson(
                                            {...old.toJson(), 'enabled': value})
                                        : old)
                                .toList());
                          }),
                Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Wrap(spacing: 8, children: [
                      TextButton.icon(
                          onPressed: () => _edit(context, p),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar')),
                      TextButton.icon(
                          onPressed: () => onProfilesChanged(profiles
                              .where(
                                  (e) => e.paperProfileId != p.paperProfileId)
                              .toList()),
                          style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Eliminar')),
                    ])),
              ]),
          ]),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Agregar tamaño de etiqueta')),
        if (enabled.length > 1) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
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
              }),
        ],
      ],
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
  late int _rotation;
  late int _darkness;
  late bool _thicken;
  String? _error;
  static const _labels = {
    'name': 'Nombre del tamaño',
    'widthMm': 'Ancho (mm)',
    'heightMm': 'Alto (mm)',
    'gapMm': 'Separación GAP (mm)',
    'leftMm': 'Izquierdo (mm)',
    'rightMm': 'Derecho (mm)',
    'topMm': 'Superior (mm)',
    'bottomMm': 'Inferior (mm)',
    'offsetXmm': 'Horizontal (mm)',
    'offsetYmm': 'Vertical (mm)',
    'scalePercent': 'Escala de calibración (%)'
  };
  @override
  void initState() {
    super.initState();
    final profile = widget.profile ??
        PaperProfile(
            paperProfileId: widget.newId,
            logicalPrinterId: widget.printerId,
            name: '',
            widthMm: 50,
            heightMm: 25);
    final data = profile.toJson();
    // Si llega un valor corrupto (edición manual del JSON guardado), que no
    // tumbe el Dropdown ni el Slider: se recorta solo para mostrarlo.
    _rotation = const [0, 90, 180, 270].contains(profile.rotation)
        ? profile.rotation
        : 0;
    _darkness = profile.darkness.clamp(0, 15);
    _thicken = profile.thicken;
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
      'enabled': widget.profile?.enabled ?? true,
      'rotation': _rotation,
      'darkness': _darkness,
      'thicken': _thicken
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

  double _mm(String key) =>
      double.tryParse(_fields[key]!.text.trim().replaceAll(',', '.')) ?? 0;

  Widget _field(String key) => TextFormField(
      controller: _fields[key],
      decoration: InputDecoration(labelText: _labels[key]),
      keyboardType: key == 'name'
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true, signed: true),
      onChanged: (_) => setState(() {}),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Completa este campo.';
        if (key != 'name' &&
            !(double.tryParse(v.replaceAll(',', '.'))?.isFinite ?? false)) {
          return 'Escribe una medida válida.';
        }
        return null;
      });

  Widget _pair(String a, String b) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _field(a)),
        const SizedBox(width: 12),
        Expanded(child: _field(b)),
      ]);

  Widget _section(String title, List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionLabel(title, padding: const EdgeInsets.fromLTRB(0, 16, 0, 0)),
        for (final child in children)
          Padding(padding: const EdgeInsets.only(top: 12), child: child),
      ]);

  /// Label drawn to scale with its margins; the text turns with the content.
  Widget _preview() {
    final w = _mm('widthMm'), h = _mm('heightMm');
    if (!(w > 0 && h > 0 && w.isFinite && h.isFinite)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    // Fixed scale (no LayoutBuilder): AlertDialog measures intrinsic sizes.
    final k = math.min(200 / w, 120 / h);
    double m(String key, {required bool horizontal}) {
      final v = _mm(key);
      final axis = horizontal ? w : h;
      return v.isFinite && v > 0 ? math.min(v, axis) * k : 0;
    }

    return Center(
        child: Container(
            width: w * k,
            height: h * k,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: scheme.outline)),
            padding: EdgeInsets.fromLTRB(
                m('leftMm', horizontal: true),
                m('topMm', horizontal: false),
                m('rightMm', horizontal: true),
                m('bottomMm', horizontal: false)),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.4))),
                child: Center(
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: RotatedBox(
                            quarterTurns: _rotation ~/ 90,
                            child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Text('ABC 123',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)))))))));
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
                        _field('name'),
                        _section('Tamaño de la etiqueta',
                            [_pair('widthMm', 'heightMm'), _field('gapMm')]),
                        _section('Márgenes', [
                          _pair('leftMm', 'rightMm'),
                          _pair('topMm', 'bottomMm')
                        ]),
                        _section('Orientación', [
                          DropdownButtonFormField<int>(
                              initialValue: _rotation,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Orientación del contenido'),
                              items: [
                                for (final e in orientationNames.entries)
                                  DropdownMenuItem(
                                      value: e.key, child: Text(e.value))
                              ],
                              onChanged: (v) =>
                                  setState(() => _rotation = v ?? 0)),
                          _preview(),
                        ]),
                        _section('Oscuridad', [
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Oscuridad personalizada'),
                              subtitle: const Text(
                                  'Si la dejas apagada, se usa la oscuridad configurada en la impresora.'),
                              value: _darkness > 0,
                              onChanged: (v) => setState(
                                  // 8 es el punto neutro de la fórmula de
                                  // ESC/POS (igual que apagada, ver
                                  // label_print.dart). En TSPL se manda como
                                  // DENSITY 8 tal cual; si la impresora real
                                  // no trae ese mismo valor de fábrica, el
                                  // primer paso puede no ser neutro ahí
                                  // (pendiente de prueba física, ver
                                  // docs/IMPRESORAS_LOGICAS.md).
                                  () => _darkness = v ? 8 : 0)),
                          if (_darkness > 0) ...[
                            Text('Nivel $_darkness de 15'),
                            Slider(
                                value: _darkness.toDouble(),
                                min: 1,
                                max: 15,
                                divisions: 14,
                                label: '$_darkness',
                                semanticFormatterCallback: (v) =>
                                    'Oscuridad ${v.round()} de 15',
                                onChanged: (v) =>
                                    setState(() => _darkness = v.round())),
                            const Text(
                                'Súbela si la etiqueta sale clara; bájala si sale muy oscura.'),
                          ],
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Trazo más grueso'),
                              subtitle: const Text(
                                  'Engrosa letras y líneas. Sirve aunque la impresora no cambie con la oscuridad. Con códigos de barras muy finos, comprueba que se sigan leyendo.'),
                              value: _thicken,
                              onChanged: (v) => setState(() => _thicken = v)),
                        ]),
                        _section('Ajuste de posición', [
                          const Text(
                              'Úsalo después de una impresión de prueba si la etiqueta sale corrida.'),
                          _pair('offsetXmm', 'offsetYmm'),
                          _field('scalePercent'),
                        ]),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                      ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(onPressed: _save, child: const Text('Guardar tamaño'))
          ]);
}
