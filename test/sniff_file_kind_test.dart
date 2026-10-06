import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_world_app/services/print_service.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('sniff_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<SniffedKind?> kindOf(String name, List<int> bytes) {
    final f = File('${dir.path}/$name')..writeAsBytesSync(bytes);
    return sniffFileKind(f.path);
  }

  test('captura PNG compartida con nombre .xml se reconoce como imagen', () async {
    expect(
      await kindOf('sunat_1.xml', [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      SniffedKind.image,
    );
  });

  test('JPEG sin extensión se reconoce como imagen', () async {
    expect(
      await kindOf('compartido_123', [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]),
      SniffedKind.image,
    );
  });

  test('WebP se reconoce como imagen', () async {
    expect(
      await kindOf('captura', [
        ...'RIFF'.codeUnits,
        0, 0, 0, 0,
        ...'WEBP'.codeUnits,
      ]),
      SniffedKind.image,
    );
  });

  test('PDF y ZIP se reconocen; XML queda sin tipo binario', () async {
    expect(await kindOf('doc', '%PDF-1.7'.codeUnits), SniffedKind.pdf);
    expect(await kindOf('cpe', [0x50, 0x4B, 0x03, 0x04, 0, 0]), SniffedKind.zip);
    expect(await kindOf('cpe.xml', '<?xml version="1.0"?>'.codeUnits), isNull);
  });
}
