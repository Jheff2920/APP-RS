import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/paper_width.dart';
import '../models/saved_printer.dart';

/// Telemetría local de rendimiento visible en logcat.
///
/// No incluye nombres de archivo, contenido del ticket, MAC ni direcciones IP.
class PrintTiming {
  PrintTiming({
    String? jobId,
    required this.source,
    required this.transport,
    required this.paper,
  }) : jobId = jobId ?? _newJobId() {
    _total.start();
    event('start');
  }

  static int _sequence = 0;

  final String jobId;
  final String source;
  final String transport;
  final String paper;
  final Stopwatch _total = Stopwatch();
  bool _finished = false;

  factory PrintTiming.forPrinter({
    String? jobId,
    required String source,
    required SavedPrinter printer,
  }) {
    return PrintTiming(
      jobId: jobId,
      source: source,
      transport: printer.type.name,
      paper: printer.paper == PaperWidth.mm58 ? '58mm' : '80mm',
    );
  }

  static String _newJobId() {
    _sequence = (_sequence + 1) & 0xffff;
    return '${DateTime.now().millisecondsSinceEpoch}-${_sequence.toRadixString(16)}';
  }

  Future<T> measure<T>(
    String phase,
    Future<T> Function() action, {
    Map<String, Object?> fields = const {},
  }) async {
    final watch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      watch.stop();
      duration(phase, watch.elapsed, fields: fields);
    }
  }

  void duration(
    String phase,
    Duration elapsed, {
    Map<String, Object?> fields = const {},
  }) {
    event(phase, fields: {
      'duration_ms': elapsed.inMicroseconds / 1000,
      ...fields,
    });
  }

  void event(
    String phase, {
    Map<String, Object?> fields = const {},
  }) {
    final payload = <String, Object?>{
      'job': jobId,
      'source': source,
      'transport': transport,
      'paper': paper,
      'phase': phase,
      'elapsed_ms': _total.elapsedMicroseconds / 1000,
      ...fields,
    };
    final encoded = jsonEncode(payload);
    developer.log(encoded, name: 'BoletaPrintTiming');
    debugPrint('BoletaPrintTiming $encoded');
  }

  void finish({
    required bool ok,
    int? bytes,
    int? pages,
  }) {
    if (_finished) return;
    _finished = true;
    _total.stop();
    event('finish', fields: {
      'ok': ok,
      if (bytes != null) 'bytes': bytes,
      if (pages != null) 'pages': pages,
      'total_ms': _total.elapsedMicroseconds / 1000,
    });
  }
}
