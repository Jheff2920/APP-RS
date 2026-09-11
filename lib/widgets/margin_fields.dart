import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/print_margins.dart';

class MarginFields extends StatefulWidget {
  const MarginFields({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PrintMargins value;
  final ValueChanged<PrintMargins> onChanged;

  @override
  State<MarginFields> createState() => _MarginFieldsState();
}

class _MarginFieldsState extends State<MarginFields> {
  late PrintMargins _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant MarginFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value != _value) {
      _value = widget.value;
    }
  }

  void _set(PrintMargins next) {
    _value = next;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        'Márgenes (mm)',
        style: theme.textTheme.titleMedium,
      ),
      children: [
        _MmField(
          label: 'Izquierdo',
          mm: _value.leftMm,
          max: 20,
          onChanged: (v) => _set(_value.copyWith(leftMm: v)),
        ),
        _MmField(
          label: 'Derecho',
          mm: _value.rightMm,
          max: 20,
          onChanged: (v) => _set(_value.copyWith(rightMm: v)),
        ),
        _MmField(
          label: 'Inferior',
          mm: _value.bottomMm,
          max: 60,
          onChanged: (v) => _set(_value.copyWith(bottomMm: v)),
        ),
      ],
    );
  }
}

class _MmField extends StatefulWidget {
  const _MmField({
    required this.label,
    required this.mm,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double mm;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  State<_MmField> createState() => _MmFieldState();
}

class _MmFieldState extends State<_MmField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  late double _mm;

  @override
  void initState() {
    super.initState();
    _mm = widget.mm;
    _ctrl = TextEditingController(text: _mm.toStringAsFixed(1));
    _focus = FocusNode();
    _focus.addListener(_syncTextIfUnfocused);
  }

  @override
  void didUpdateWidget(covariant _MmField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mm != widget.mm && !_focus.hasFocus) {
      _mm = widget.mm;
      _syncTextIfUnfocused();
    }
  }

  void _syncTextIfUnfocused() {
    if (_focus.hasFocus) return;
    final next = _mm.toStringAsFixed(1);
    if (_ctrl.text != next) {
      _ctrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  void _setMm(double next) {
    final clamped = next.clamp(0.0, widget.max);
    if (clamped == _mm) return;
    setState(() => _mm = clamped);
    widget.onChanged(clamped);
    _syncTextIfUnfocused();
  }

  void _applyRaw(String raw) {
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed == null) return;
    final clamped = parsed.clamp(0.0, widget.max);
    if (clamped == _mm) return;
    setState(() => _mm = clamped);
    widget.onChanged(clamped);
  }

  @override
  void dispose() {
    _focus.removeListener(_syncTextIfUnfocused);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 88, child: Text(widget.label)),
        Expanded(
          child: RepaintBoundary(
            child: Slider(
              value: _mm.clamp(0.0, widget.max),
              min: 0,
              max: widget.max,
              divisions: (widget.max * 2).round(),
              label: '${_mm.toStringAsFixed(1)} mm',
              onChanged: _setMm,
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: TextFormField(
            controller: _ctrl,
            focusNode: _focus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              isDense: true,
              suffixText: 'mm',
            ),
            onChanged: _applyRaw,
            onFieldSubmitted: _applyRaw,
          ),
        ),
      ],
    );
  }
}
