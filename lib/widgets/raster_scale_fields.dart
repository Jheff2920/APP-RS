import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../models/raster_scale.dart';
import 'ui_kit.dart';

class RasterScaleFields extends StatelessWidget {
  const RasterScaleFields({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RasterScale value;
  final ValueChanged<RasterScale> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = L.of(context);
    return ExpansionTile(
      initiallyExpanded: false,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.fromLTRB(14, 4, 16, 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      leading: const IconTile(icon: Icons.hd_outlined, size: 40),
      title: Text(
        l('Nitidez', 'Sharpness'),
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${value.label}, ${value.hint}',
        style: theme.textTheme.bodySmall,
      ),
      children: [
        Text(
          l(
            'x1 es el más rápido. x2 y x3 se ven más nítidos; el ticket mide lo mismo. '
            'Por Bluetooth, cuanto más alto, más tarda en salir la impresión.',
            'x1 is the fastest. x2 and x3 look sharper; ticket size stays the same. '
            'Over Bluetooth, the higher the setting, the longer the print takes.',
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SegmentedButton<RasterScale>(
          expandedInsets: EdgeInsets.zero,
          showSelectedIcon: false,
          segments: [
            for (final s in RasterScale.values)
              ButtonSegment(value: s, label: Text(s.label)),
          ],
          selected: {value},
          onSelectionChanged: (set) {
            if (set.isEmpty) return;
            onChanged(set.first);
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(value.detail, style: theme.textTheme.labelMedium),
        ),
      ],
    );
  }
}
