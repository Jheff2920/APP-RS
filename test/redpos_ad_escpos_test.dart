import 'package:flutter_test/flutter_test.dart';
import 'package:hello_world_app/models/cut_mode.dart';
import 'package:hello_world_app/models/paper_width.dart';
import 'package:hello_world_app/services/redpos/redpos_ad_escpos.dart';

void main() {
  test('inserts footer immediately before GS V 0 cut', () {
    final ticket = <int>[1, 2, 3, ...CutMode.fullGsV0.escPosBytes];
    final footer = RedPosAdEscPos.footerBytes(paper: PaperWidth.mm58);
    final out = RedPosAdEscPos.insertBeforeFeedAndCut(
      ticket,
      footer,
      CutMode.fullGsV0.escPosBytes,
    );
    expect(out.sublist(out.length - 3), CutMode.fullGsV0.escPosBytes);
    expect(out.sublist(0, 3), [1, 2, 3]);
    expect(out.sublist(3, 3 + footer.length), footer);
  });

  test('puts ads before blank GS v 0 feed so they sit against the ticket', () {
    final blank = <int>[
      0x1d, 0x76, 0x30, 0x00,
      2, 0, // 2 bytes/row
      4, 0, // 4 rows
      0, 0, 0, 0, 0, 0, 0, 0,
    ];
    final ticket = <int>[9, 8, 7, ...blank, ...CutMode.fullGsV0.escPosBytes];
    final footer = RedPosAdEscPos.footerBytes(paper: PaperWidth.mm58);
    final out = RedPosAdEscPos.insertBeforeFeedAndCut(
      ticket,
      footer,
      CutMode.fullGsV0.escPosBytes,
    );
    expect(out.sublist(0, 3), [9, 8, 7]);
    expect(out.sublist(3, 3 + footer.length), footer);
    expect(
      out.sublist(3 + footer.length, 3 + footer.length + blank.length),
      blank,
    );
    expect(out.sublist(out.length - 3), CutMode.fullGsV0.escPosBytes);
  });

  test('appends footer when there is no cut', () {
    final ticket = <int>[9, 8, 7];
    final footer = RedPosAdEscPos.footerBytes(paper: PaperWidth.mm80);
    final out = RedPosAdEscPos.insertBeforeFeedAndCut(ticket, footer, const []);
    expect(out.take(3).toList(), [9, 8, 7]);
    expect(out.sublist(3, 3 + footer.length), footer);
  });

  test('footer includes site url and is ASCII', () {
    final bytes = RedPosAdEscPos.footerBytes(
      paper: PaperWidth.mm58,
      siteUrl: 'www.redsoluciones.com.pe',
    );
    final text = String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));
    expect(text.contains('App de uso gratuito'), isTrue);
    expect(text.contains('www.redsoluciones.com.pe'), isTrue);
    expect(bytes.contains(0x1d), isFalse);
  });
}
