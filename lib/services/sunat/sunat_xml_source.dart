import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'sunat_ubl_parser.dart';

/// Lee XML SUNAT desde un `.xml` o un `.zip` (CPE + CDR).
class SunatXmlSource {
  static final _cpeFileName = RegExp(
    r'^\d{11}-\d{2}-.+\.xml$',
    caseSensitive: false,
  );

  static const _cpeRoots = [
    'Invoice',
    'CreditNote',
    'DebitNote',
    'DespatchAdvice',
    'Retention',
    'Perception',
    'SelfBilledInvoice',
  ];

  static const _skipRoots = [
    'ApplicationResponse',
    'VoidedDocuments',
    'SummaryDocuments',
  ];

  static Future<String> load(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    if (bytes.isEmpty) {
      throw SunatXmlException('El archivo esta vacio.');
    }
    if (_isZip(bytes) || filePath.toLowerCase().endsWith('.zip')) {
      return decode(_xmlFromZip(bytes));
    }
    return decode(bytes);
  }

  static String decode(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  static bool _isZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);
  }

  static List<int> _xmlFromZip(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (_) {
      throw SunatXmlException('No se pudo abrir el ZIP de SUNAT.');
    }

    final xmlFiles = archive.files.where((f) {
      if (!f.isFile) return false;
      return p.basename(f.name).toLowerCase().endsWith('.xml');
    }).toList();

    if (xmlFiles.isEmpty) {
      throw SunatXmlException('El ZIP no contiene un XML de SUNAT.');
    }

    ArchiveFile? cpe;
    for (final f in xmlFiles) {
      if (_isCpeFile(f)) {
        cpe = f;
        break;
      }
    }
    cpe ??= xmlFiles.firstWhere(
      (f) {
        final n = p.basename(f.name);
        return !n.toLowerCase().startsWith('r-');
      },
      orElse: () => xmlFiles.first,
    );

    final content = cpe.readBytes();
    if (content == null || content.isEmpty) {
      throw SunatXmlException('El XML dentro del ZIP esta vacio.');
    }
    return content;
  }

  static bool _isCpeFile(ArchiveFile f) {
    final name = p.basename(f.name);
    if (name.toLowerCase().startsWith('r-')) return false;
    if (_cpeFileName.hasMatch(name)) return true;
    final content = f.readBytes();
    if (content == null || content.isEmpty) return false;
    final take = content.length < 8192 ? content.length : 8192;
    final head = utf8.decode(content.sublist(0, take), allowMalformed: true);
    if (_skipRoots.any((r) => head.contains('<$r'))) return false;
    return _cpeRoots.any((r) => head.contains('<$r'));
  }
}
