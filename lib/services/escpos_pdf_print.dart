import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';

import '../models/paper_width.dart';
import '../models/saved_printer.dart';
import 'escpos_capability_profile.dart';
import 'escpos_feed.dart';
import 'escpos_gs_v0.dart';
import 'print_timing.dart';

class EscPosPdfPrint {
  /// Rasteriza PDF como imagen térmica (estilo apps tipo RawBT).
  /// El trabajo pesado de imagen va en un isolate para no congelar la UI.
  static Future<List<int>> build(
    SavedPrinter printer, {
    required String filePath,
    int maxPages = 8,
    PrintTiming? timing,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('No se encontro el archivo: $filePath');
    }

    final profile = await _timed(
      timing,
      'capability_profile',
      () => EscPosCapabilityProfile.load,
    );
    final paperSize =
        printer.paper == PaperWidth.mm58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paperSize, profile);
    final layout = _layout(printer);

    // openData evita cuelgues de openFile con paths del PrintService/cache.
    final raw = await _timed(timing, 'read_pdf', file.readAsBytes);
    final doc = await _timed(
      timing,
      'open_pdf',
      () => PdfDocument.openData(raw).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Tiempo agotado abriendo el PDF'),
      ),
    );
    _RasterWorker? worker;
    try {
      worker = await _timed(
        timing,
        'image_worker_start',
        _RasterWorker.start,
      );
      final bytes = <int>[...generator.reset()];

      final pages = math.min(doc.pagesCount, maxPages);
      for (var i = 1; i <= pages; i++) {
        final page = await doc.getPage(i);
        try {
          final png = await _timed(
            timing,
            'render_page',
            () => _renderPagePng(page, layout),
            fields: {'page': i},
          );
          if (png == null) continue;

          final band = await _timed(
            timing,
            'encode_page',
            () => worker!.encode(
              pngBytes: png,
              fullWidth: layout.fullWidth,
              leftPad: layout.leftPad,
              contentWidth: layout.contentWidth,
            ),
            fields: {'page': i},
          );
          if (band.isEmpty) continue;
          bytes.addAll(band);
          if (i < pages) {
            bytes.addAll(generator.feed(1));
          }
        } finally {
          await page.close();
        }
      }

      // Ajustes de la impresora: margen inferior (+ corte si aplica).
      bytes.addAll(
        EscPosFeed.finishJob(
          bottomMm: printer.margins.bottomMm,
          paperDotsWidth: layout.fullWidth,
          cut: printer.cut,
        ),
      );
      timing?.event('raster_complete', fields: {
        'pages': pages,
        'bytes': bytes.length,
      });
      return bytes;
    } finally {
      await worker?.close();
      await doc.close();
    }
  }

  static Future<List<int>> buildImageFile(
    SavedPrinter printer, {
    required String filePath,
    PrintTiming? timing,
  }) async {
    final data = await _timed(
      timing,
      'read_image',
      () => File(filePath).readAsBytes(),
    );
    final layout = _layout(printer);

    final body = await _timed(
      timing,
      'encode_image',
      () => Isolate.run(
        () => _encodePngToGsV0(
          pngBytes: data,
          fullWidth: layout.fullWidth,
          leftPad: layout.leftPad,
          contentWidth: layout.contentWidth,
        ),
      ),
    );
    if (body.isEmpty) {
      throw Exception('No se pudo leer la imagen');
    }

    final profile = await _timed(
      timing,
      'capability_profile',
      () => EscPosCapabilityProfile.load,
    );
    final paperSize =
        printer.paper == PaperWidth.mm58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paperSize, profile);

    final bytes = <int>[
      ...generator.reset(),
      ...body,
      ...EscPosFeed.finishJob(
        bottomMm: printer.margins.bottomMm,
        paperDotsWidth: layout.fullWidth,
        cut: printer.cut,
      ),
    ];
    timing?.event('raster_complete', fields: {
      'pages': 1,
      'bytes': bytes.length,
    });
    return bytes;
  }

  static _PrintLayout _layout(SavedPrinter printer) {
    final fullWidth = _dotsWidth(printer.paper);
    final dotsPerMm = fullWidth / printer.paper.printableWidthMm;
    final left =
        (printer.margins.leftMm * dotsPerMm).round().clamp(0, fullWidth - 8);
    final right =
        (printer.margins.rightMm * dotsPerMm).round().clamp(0, fullWidth - 8);
    var contentWidth = fullWidth - left - right;
    if (contentWidth < 8) contentWidth = 8;
    contentWidth -= contentWidth % 8;
    return _PrintLayout(
      fullWidth: fullWidth,
      leftPad: left,
      contentWidth: contentWidth,
    );
  }

  static int _dotsWidth(PaperWidth paper) {
    final raw = paper == PaperWidth.mm58 ? 384 : 576;
    return raw - (raw % 8);
  }

  static Future<Uint8List?> _renderPagePng(
    PdfPage page,
    _PrintLayout layout,
  ) async {
    final renderWidth = layout.contentWidth.toDouble();
    final renderHeight = page.height * (renderWidth / page.width);
    final pageImage = await page
        .render(
          width: renderWidth,
          height: renderHeight,
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFFFF',
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw Exception('Tiempo agotado rasterizando el PDF'),
        );
    return pageImage?.bytes;
  }
}

/// Top-level para Isolate.run (debe ser funcion publica/top-level).
List<int> _encodePngToGsV0({
  required List<int> pngBytes,
  required int fullWidth,
  required int leftPad,
  required int contentWidth,
}) {
  final prepared = _prepareBitmap(
    pngBytes,
    contentWidth: contentWidth,
  );
  if (prepared == null) return const [];
  return EscPosGsV0.encodeLuminance(
    prepared,
    threshold: _thresholdFor(prepared),
    outputWidth: fullWidth,
    leftPad: leftPad,
  );
}

img.Image? _prepareBitmap(
  List<int> bytes, {
  required int contentWidth,
}) {
  final decoded = img.decodeImage(Uint8List.fromList(bytes));
  if (decoded == null) return null;

  final canvas = img.Image(
    width: decoded.width,
    height: decoded.height,
    numChannels: 3,
  );
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(canvas, decoded);

  // Solo blanco superior/inferior; márgenes L/R los define la config.
  var work = _cropInkVertical(canvas) ?? canvas;

  if (_averageLuminance(work) < 90) {
    work = img.invert(work);
  }

  work = img.copyResize(
    work,
    width: contentWidth,
    interpolation: img.Interpolation.average,
  );

  if (work.width != contentWidth) {
    if (work.width > contentWidth) {
      work = img.copyCrop(
        work,
        x: 0,
        y: 0,
        width: contentWidth,
        height: work.height,
      );
    } else {
      final fitted = img.Image(
        width: contentWidth,
        height: work.height,
        numChannels: 3,
      );
      img.fill(fitted, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(fitted, work, dstX: 0, dstY: 0);
      work = fitted;
    }
  }
  return work;
}

img.Image? _cropInkVertical(img.Image image) {
  int? minY;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      if (p.r + p.g + p.b <= 750) {
        minY = y;
        break;
      }
    }
    if (minY != null) break;
  }
  if (minY == null) return null;

  int? maxY;
  for (var y = image.height - 1; y >= minY; y--) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      if (p.r + p.g + p.b <= 750) {
        maxY = y;
        break;
      }
    }
    if (maxY != null) break;
  }
  if (maxY == null) return null;

  maxY = (maxY + 1).clamp(0, image.height - 1);
  final h = maxY - minY + 1;
  if (h < 8) return null;

  return img.copyCrop(
    image,
    x: 0,
    y: minY,
    width: image.width,
    height: h,
  );
}

int _thresholdFor(img.Image work) {
  var sum = 0;
  var count = 0;
  for (var y = 0; y < work.height; y += 3) {
    for (var x = 0; x < work.width; x += 3) {
      final p = work.getPixel(x, y);
      sum += (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
      count++;
    }
  }
  var threshold = count == 0 ? 140 : sum ~/ count;
  if (threshold < 100) threshold = 100;
  if (threshold > 200) threshold = 200;
  return threshold;
}

double _averageLuminance(img.Image image) {
  var sum = 0.0;
  var count = 0;
  for (var y = 0; y < image.height; y += 8) {
    for (var x = 0; x < image.width; x += 8) {
      final p = image.getPixel(x, y);
      sum += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      count++;
    }
  }
  return count == 0 ? 255 : sum / count;
}

Future<T> _timed<T>(
  PrintTiming? timing,
  String phase,
  Future<T> Function() action, {
  Map<String, Object?> fields = const {},
}) {
  return timing?.measure(phase, action, fields: fields) ?? action();
}

/// Un worker por documento evita pagar el arranque de un isolate por página.
class _RasterWorker {
  _RasterWorker(this._isolate, this._requests);

  final Isolate _isolate;
  final SendPort _requests;
  bool _closed = false;

  static Future<_RasterWorker> start() async {
    final ready = ReceivePort();
    try {
      final isolate = await Isolate.spawn(_rasterWorkerMain, ready.sendPort);
      final requests = await ready.first.timeout(const Duration(seconds: 10));
      return _RasterWorker(isolate, requests as SendPort);
    } finally {
      ready.close();
    }
  }

  Future<List<int>> encode({
    required Uint8List pngBytes,
    required int fullWidth,
    required int leftPad,
    required int contentWidth,
  }) async {
    if (_closed) throw StateError('Raster worker cerrado');
    final response = ReceivePort();
    try {
      _requests.send(<String, Object>{
        'command': 'encode',
        'reply': response.sendPort,
        'png': TransferableTypedData.fromList([pngBytes]),
        'fullWidth': fullWidth,
        'leftPad': leftPad,
        'contentWidth': contentWidth,
      });
      final result = await response.first.timeout(const Duration(seconds: 45));
      if (result is TransferableTypedData) {
        return result.materialize().asUint8List();
      }
      if (result is Map && result['error'] != null) {
        throw StateError('Raster worker: ${result['error']}');
      }
      throw StateError('Respuesta invalida del raster worker');
    } finally {
      response.close();
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final response = ReceivePort();
    try {
      _requests.send(<String, Object>{
        'command': 'close',
        'reply': response.sendPort,
      });
      await response.first.timeout(const Duration(seconds: 2));
    } catch (_) {
      // kill() garantiza limpieza si el worker no responde.
    } finally {
      response.close();
      _isolate.kill(priority: Isolate.immediate);
    }
  }
}

void _rasterWorkerMain(SendPort ready) {
  final requests = ReceivePort();
  ready.send(requests.sendPort);
  requests.listen((dynamic message) {
    final request = Map<Object?, Object?>.from(message as Map);
    final reply = request['reply'] as SendPort;
    if (request['command'] == 'close') {
      reply.send(true);
      requests.close();
      return;
    }

    try {
      final png =
          (request['png'] as TransferableTypedData).materialize().asUint8List();
      final bytes = _encodePngToGsV0(
        pngBytes: png,
        fullWidth: request['fullWidth'] as int,
        leftPad: request['leftPad'] as int,
        contentWidth: request['contentWidth'] as int,
      );
      reply.send(
        TransferableTypedData.fromList([Uint8List.fromList(bytes)]),
      );
    } catch (error) {
      reply.send(<String, String>{'error': error.runtimeType.toString()});
    }
  });
}

class _PrintLayout {
  const _PrintLayout({
    required this.fullWidth,
    required this.leftPad,
    required this.contentWidth,
  });

  final int fullWidth;
  final int leftPad;
  final int contentWidth;
}
