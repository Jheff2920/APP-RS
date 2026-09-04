import 'package:flutter/material.dart';

import '../models/paper_width.dart';

class PaperWidthSelector extends StatelessWidget {
  const PaperWidthSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PaperWidth value;
  final ValueChanged<PaperWidth> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PaperWidth>(
      segments: const [
        ButtonSegment(value: PaperWidth.mm58, label: Text('58 mm')),
        ButtonSegment(value: PaperWidth.mm80, label: Text('80 mm')),
      ],
      selected: {value},
      onSelectionChanged: (set) {
        if (set.isNotEmpty) onChanged(set.first);
      },
    );
  }
}
