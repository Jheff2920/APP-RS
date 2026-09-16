import 'package:flutter_test/flutter_test.dart';
import 'package:hello_world_app/models/cut_mode.dart';
import 'package:hello_world_app/services/escpos_feed.dart';

void main() {
  test('LAN finish uses ESC d and GS V 0x00, not blank GS v 0', () {
    final out = EscPosFeed.finishJob(
      bottomMm: 15,
      paperDotsWidth: 384,
      cut: CutMode.fullGsV0,
      network: true,
    );
    expect(out.take(2).toList(), [0x1b, 0x64]);
    expect(out.last, 0x00);
    expect(out.sublist(out.length - 3), [0x1d, 0x56, 0x00]);
    expect(out.contains(0x76), isFalse);
  });

  test('Bluetooth finish still uses blank GS v 0 tear-off', () {
    final out = EscPosFeed.finishJob(
      bottomMm: 15,
      paperDotsWidth: 384,
      cut: CutMode.fullGsV0,
    );
    expect(out.take(2).toList(), [0x1d, 0x76]);
    expect(out.sublist(out.length - 3), CutMode.fullGsV0.escPosBytes);
  });
}
