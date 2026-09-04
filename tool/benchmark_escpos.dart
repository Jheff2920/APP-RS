import 'dart:io';

import 'package:hello_world_app/services/escpos_gs_v0.dart';
import 'package:image/image.dart' as img;

void main() {
  const threshold = 145;
  const outputWidth = 576;
  const leftPad = 8;
  final source = _sampleImage(width: 560, height: 1800);

  // Calentar JIT y caches.
  _legacyThresholdAndPack(
    img.Image.from(source),
    threshold: threshold,
    outputWidth: outputWidth,
    leftPad: leftPad,
  );
  EscPosGsV0.encodeLuminance(
    source,
    threshold: threshold,
    outputWidth: outputWidth,
    leftPad: leftPad,
    trimVertical: false,
  );

  final legacyTimes = <int>[];
  final fusedTimes = <int>[];
  List<int>? expected;
  List<int>? actual;
  for (var run = 0; run < 7; run++) {
    final legacyInput = img.Image.from(source);
    final legacyWatch = Stopwatch()..start();
    expected = _legacyThresholdAndPack(
      legacyInput,
      threshold: threshold,
      outputWidth: outputWidth,
      leftPad: leftPad,
    );
    legacyWatch.stop();
    legacyTimes.add(legacyWatch.elapsedMicroseconds);

    final fusedInput = img.Image.from(source);
    final fusedWatch = Stopwatch()..start();
    actual = EscPosGsV0.encodeLuminance(
      fusedInput,
      threshold: threshold,
      outputWidth: outputWidth,
      leftPad: leftPad,
      trimVertical: false,
    );
    fusedWatch.stop();
    fusedTimes.add(fusedWatch.elapsedMicroseconds);
  }

  if (!_sameBytes(expected!, actual!)) {
    throw StateError('El encoder fusionado no coincide con el anterior');
  }
  final legacyMedian = _median(legacyTimes);
  final fusedMedian = _median(fusedTimes);
  final improvement = (1 - fusedMedian / legacyMedian) * 100;
  stdout.writeln(
    'legacy_median_ms=${(legacyMedian / 1000).toStringAsFixed(2)}',
  );
  stdout.writeln(
    'fused_median_ms=${(fusedMedian / 1000).toStringAsFixed(2)}',
  );
  stdout.writeln('improvement_percent=${improvement.toStringAsFixed(1)}');
  stdout.writeln('bytes=${actual.length}');
}

List<int> _legacyThresholdAndPack(
  img.Image work, {
  required int threshold,
  required int outputWidth,
  required int leftPad,
}) {
  for (var y = 0; y < work.height; y++) {
    for (var x = 0; x < work.width; x++) {
      final pixel = work.getPixel(x, y);
      final luminance =
          (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).round();
      final value = luminance > threshold ? 255 : 0;
      work.setPixelRgb(x, y, value, value, value);
    }
  }
  final sheet = img.Image(
    width: outputWidth,
    height: work.height,
    numChannels: 3,
  );
  img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(sheet, work, dstX: leftPad);
  return EscPosGsV0.encode(sheet);
}

img.Image _sampleImage({required int width, required int height}) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final value = (x * 13 + y * 7 + (x * y) % 97) & 0xff;
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  return image;
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
