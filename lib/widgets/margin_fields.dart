import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/print_margins.dart';

class MarginFields extends StatelessWidget {
  const MarginFields({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PrintMargins value;
  final ValueChanged<PrintMargins> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Margenes de software (mm)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Estos valores mandan en PDF, imagen y pagina de prueba. '
          'Izquierdo/derecho: blanco dentro del area imprimible. '
          'Inferior: avance al terminar; si hay cuchilla, se avanza y luego se corta.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _slider(
          label: 'Izquierdo',
          mm: value.leftMm,
          max: 20,
          onChanged: (v) => onChanged(value.copyWith(leftMm: v)),
        ),
        _slider(
          label: 'Derecho',
          mm: value.rightMm,
          max: 20,
          onChanged: (v) => onChanged(value.copyWith(rightMm: v)),
        ),
        _slider(
          label: 'Inferior',
          mm: value.bottomMm,
          max: 60,
          onChanged: (v) => onChanged(value.copyWith(bottomMm: v)),
        ),
      ],
    );
  }

  Widget _slider({
    required String label,
    required double mm,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    void applyRaw(String raw) {
      final parsed = double.tryParse(raw.replaceAll(',', '.'));
      if (parsed != null) {
        onChanged(parsed.clamp(0, max));
      }
    }

    return Row(
      children: [
        SizedBox(width: 88, child: Text(label)),
        Expanded(
          child: Slider(
            value: mm.clamp(0, max),
            min: 0,
            max: max,
            divisions: (max * 2).round(),
            label: '${mm.toStringAsFixed(1)} mm',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 56,
          child: TextFormField(
            key: ValueKey('$label-${mm.toStringAsFixed(1)}'),
            initialValue: mm.toStringAsFixed(1),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              isDense: true,
              suffixText: 'mm',
            ),
            onChanged: applyRaw,
            onFieldSubmitted: applyRaw,
            onEditingComplete: () {},
          ),
        ),
      ],
    );
  }
}
