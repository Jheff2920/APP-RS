import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:hello_world_app/services/escpos_gs_v0.dart';

void main() {
  group('EscPosGsV0.encodeLuminance', () {
    test('packs thresholded pixels with an unaligned left margin', () {
      final image = _whiteImage(width: 8, height: 8);
      for (var y = 0; y < image.height; y++) {
        image.setPixelRgb(0, y, 0, 0, 0);
        image.setPixelRgb(7, y, 0, 0, 0);
      }

      final bytes = EscPosGsV0.encodeLuminance(
        image,
        threshold: 128,
        outputWidth: 16,
        leftPad: 3,
      );

      expect(bytes.sublist(0, 8), [0x1d, 0x76, 0x30, 0, 2, 0, 8, 0]);
      expect(
          bytes.sublist(8),
          List<int>.generate(16, (i) {
            return i.isEven ? 0x10 : 0x20;
          }));
    });

    test('trims vertical white space but keeps at least eight rows', () {
      final image = _whiteImage(width: 8, height: 20);
      for (var y = 5; y <= 12; y++) {
        image.setPixelRgb(0, y, 0, 0, 0);
      }

      final bytes = EscPosGsV0.encodeLuminance(
        image,
        threshold: 128,
        outputWidth: 8,
      );

      expect(bytes.sublist(0, 8), [0x1d, 0x76, 0x30, 0, 1, 0, 8, 0]);
      expect(bytes.sublist(8), List<int>.filled(8, 0x80));
    });

    test('matches the previous threshold-then-pack result', () {
      final source = img.Image(width: 8, height: 8, numChannels: 3);
      final legacyContent = img.Image(width: 8, height: 8, numChannels: 3);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          final value = (x * 31 + y * 17) & 0xff;
          source.setPixelRgb(x, y, value, value, value);
          final mono = value > 140 ? 255 : 0;
          legacyContent.setPixelRgb(x, y, mono, mono, mono);
        }
      }
      final legacySheet = _whiteImage(width: 16, height: 8);
      img.compositeImage(legacySheet, legacyContent, dstX: 3);

      final previous = EscPosGsV0.encode(legacySheet);
      final fused = EscPosGsV0.encodeLuminance(
        source,
        threshold: 140,
        outputWidth: 16,
        leftPad: 3,
        trimVertical: false,
      );

      expect(fused, previous);
    });

    test('preserves 512-row band boundaries', () {
      final image = img.Image(width: 8, height: 513, numChannels: 3);
      img.fill(image, color: img.ColorRgb8(0, 0, 0));

      final bytes = EscPosGsV0.encodeLuminance(
        image,
        threshold: 128,
        outputWidth: 8,
      );

      expect(bytes.sublist(0, 8), [0x1d, 0x76, 0x30, 0, 1, 0, 0, 2]);
      final secondHeader = 8 + 512;
      expect(
        bytes.sublist(secondHeader, secondHeader + 8),
        [0x1d, 0x76, 0x30, 0, 1, 0, 1, 0],
      );
    });
  });
}

img.Image _whiteImage({required int width, required int height}) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  return image;
}
