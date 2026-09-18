import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:hello_world_app/services/escpos_image_prep.dart';

void main() {
  test('crops the bright voucher out of a screenshot-like image', () {
    final shot = img.Image(width: 200, height: 400, numChannels: 3);
    img.fill(shot, color: img.ColorRgb8(70, 90, 140));
    for (var y = 90; y < 310; y++) {
      for (var x = 40; x < 160; x++) {
        shot.setPixelRgb(x, y, 250, 250, 250);
      }
    }
    for (var y = 120; y < 140; y++) {
      for (var x = 50; x < 150; x++) {
        shot.setPixelRgb(x, y, 20, 20, 20);
      }
    }

    final cropped = EscPosImagePrep.cropVoucher(shot);
    expect(cropped.width, lessThan(shot.width));
    expect(cropped.height, lessThan(shot.height));
    expect(cropped.width, greaterThan(100));
    expect(cropped.height, greaterThan(160));
    final p = cropped.getPixel(cropped.width ~/ 2, cropped.height ~/ 2);
    expect(p.r.toInt() + p.g.toInt() + p.b.toInt(), greaterThan(700));
  });

  test('keeps an already-cropped white ticket', () {
    final ticket = img.Image(width: 120, height: 220, numChannels: 3);
    img.fill(ticket, color: img.ColorRgb8(255, 255, 255));
    for (var x = 10; x < 110; x++) {
      ticket.setPixelRgb(x, 40, 0, 0, 0);
    }
    final cropped = EscPosImagePrep.cropVoucher(ticket);
    expect(cropped.width, ticket.width);
    expect(cropped.height, ticket.height);
  });

  test('caps a pale BCP voucher so gray chrome stays paper', () {
    final voucher = img.Image(width: 96, height: 160, numChannels: 3);
    img.fill(voucher, color: img.ColorRgb8(255, 255, 255));
    for (var y = 28; y < 52; y++) {
      for (var x = 16; x < 80; x++) {
        voucher.setPixelRgb(x, y, 3, 28, 98);
      }
    }
    for (var y = 64; y < 80; y++) {
      for (var x = 28; x < 68; x++) {
        voucher.setPixelRgb(x, y, 235, 241, 253);
      }
    }
    for (var y = 120; y < 136; y++) {
      for (var x = 0; x < 96; x++) {
        voucher.setPixelRgb(x, y, 233, 238, 246);
      }
    }

    final threshold = EscPosImagePrep.thresholdFor(
      voucher,
      minThreshold: EscPosImagePrep.sharedMinThreshold,
      maxThreshold: EscPosImagePrep.sharedMaxThreshold,
    );
    expect(threshold, EscPosImagePrep.sharedMaxThreshold);

    int lum(int r, int g, int b) =>
        (0.299 * r + 0.587 * g + 0.114 * b).round();
    expect(lum(3, 28, 98), lessThanOrEqualTo(threshold));
    expect(lum(235, 241, 253), greaterThan(threshold));
    expect(lum(233, 238, 246), greaterThan(threshold));
  });
}
