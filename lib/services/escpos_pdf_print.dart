import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';

import '../models/paper_width.dart';
import '../models/saved_printer.dart';
import '../models/system_print_media.dart';
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
    String? systemMediaSizeId,
    int? mediaWidthMils,
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
    final layout = _layout(
      printer,
      systemMediaSizeId: systemMediaSizeId,
      mediaWidthMils: mediaWidthMils,
    );
    final paperSize = _paperSize(layout.paper);
    final generator = Generator(paperSize, profile);

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
    try {
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
            () async => _encodePngToGsV0(
              pngBytes: png,
              fullWidth: layout.fullWidth,
              leftPad: layout.leftPad,
              contentWidth: layout.contentWidth,
              trimChromeMargins: layout.chromeFit,
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

      // Ajustes de la impresora: margen inferior + corte + gaveta.
      bytes.addAll(
        EscPosFeed.finishJob(
          bottomMm: printer.margins.bottomMm,
          paperDotsWidth: layout.fullWidth,
          cut: printer.cut,
          dotsPerMm: printer.dpi.dotsPerMm,
        ),
      );
      timing?.event('raster_complete', fields: {
        'pages': pages,
        'bytes': bytes.length,
      });
      return bytes;
    } finally {
      await doc.close();
    }
  }

  static Future<List<int>> buildImageFile(
    SavedPrinter printer, {
    required String filePath,
    PrintTiming? timing,
    String? systemMediaSizeId,
    int? mediaWidthMils,
  }) async {
    final data = await _timed(
      timing,
      'read_image',
      () => File(filePath).readAsBytes(),
    );
    final layout = _layout(
      printer,
      systemMediaSizeId: systemMediaSizeId,
      mediaWidthMils: mediaWidthMils,
    );

    final body = await _timed(
      timing,
      'encode_image',
      () async => _encodePngToGsV0(
        pngBytes: data,
        fullWidth: layout.fullWidth,
        leftPad: layout.leftPad,
        contentWidth: layout.contentWidth,
        trimChromeMargins: layout.chromeFit,
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
    final paperSize = _paperSize(layout.paper);
    final generator = Generator(paperSize, profile);

    final bytes = <int>[
      ...generator.reset(),
      ...body,
      ...EscPosFeed.finishJob(
        bottomMm: printer.margins.bottomMm,
        paperDotsWidth: layout.fullWidth,
        cut: printer.cut,
        dotsPerMm: printer.dpi.dotsPerMm,
      ),
    ];
    timing?.event('raster_complete', fields: {
      'pages': 1,
      'bytes': bytes.length,
    });
    return bytes;
  }

  static _PrintLayout _layout(
    SavedPrinter printer, {
    String? systemMediaSizeId,
    int? mediaWidthMils,
  }) {
    final media = SystemPrintMedia.fromJob(
      id: systemMediaSizeId,
      widthMils: mediaWidthMils,
    );
    final paper = media?.paper ?? printer.paper;
    final fullWidth = printer.dpi.dotsFor(paper);
    // Del diálogo Imprimir: recortar el ticket y llenar 58/80.
    // Compartir/POS (sin media): 1:1 sin estirar.
    return _PrintLayout(
      fullWidth: fullWidth,
      leftPad: 0,
      contentWidth: fullWidth,
      paper: paper,
      chromeFit: media?.chromeFit ?? false,
      rasterScale: printer.rasterScale.factor,
    );
  }

  static PaperSize _paperSize(PaperWidth paper) {
    return paper == PaperWidth.mm58 ? PaperSize.mm58 : PaperSize.mm80;
  }

  static double _renderWidthPx(_PrintLayout layout) {
    return (layout.fullWidth * layout.rasterScale).toDouble();
  }

  static Future<Uint8List?> _renderPagePng(
    PdfPage page,
    _PrintLayout layout,
  ) async {
    final renderWidth = _renderWidthPx(layout);
    var renderHeight = page.height * (renderWidth / page.width);
    if (renderHeight < 8) renderHeight = 8;
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
  bool trimChromeMargins = false,
}) {
  final prepared = _prepareBitmap(
    pngBytes,
    fullWidth: fullWidth,
    trimChromeMargins: trimChromeMargins,
  );
  if (prepared == null) return const [];
  return EscPosGsV0.encodeLuminance(
    prepared,
    threshold: _thresholdFor(prepared),
    outputWidth: fullWidth,
    leftPad: 0,
    trimVertical: true,
  );
}

/// Compartir/POS: no recortar ni estirar. Chrome: recortar el ticket y
/// ajustarlo al ancho del rollo (escala uniforme, no deforma).
img.Image? _prepareBitmap(
  List<int> bytes, {
  required int fullWidth,
  bool trimChromeMargins = false,
}) {
  final decoded = img.decodeImage(Uint8List.fromList(bytes));
  if (decoded == null) return null;

  var work = decoded;
  if (work.numChannels != 3) {
    final canvas = img.Image(
      width: work.width,
      height: work.height,
      numChannels: 3,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, work);
    work = canvas;
  }

  if (_averageLuminance(work) < 90) {
    work = img.invert(work);
  }

  if (trimChromeMargins) {
    work = _trimInkFrame(work);
  }

  return _alignToFullWidth(
    work,
    fullWidth,
    scaleToFill: trimChromeMargins || work.width > fullWidth + 8,
  );
}

/// Recorta el marco de tinta. Gris casi blanco (R+G+B > 720) cuenta como papel.
img.Image _trimInkFrame(img.Image work) {
  bool isInk(img.Pixel p) => (p.r + p.g + p.b) <= 720;

  var top = -1;
  var bottom = -1;
  for (var y = 0; y < work.height; y++) {
    var ink = false;
    for (var x = 0; x < work.width; x++) {
      if (isInk(work.getPixel(x, y))) {
        ink = true;
        break;
      }
    }
    if (ink) {
      if (top < 0) top = y;
      bottom = y;
    }
  }
  if (top < 0) return work;

  var left = -1;
  var right = -1;
  for (var x = 0; x < work.width; x++) {
    var ink = false;
    for (var y = top; y <= bottom; y++) {
      if (isInk(work.getPixel(x, y))) {
        ink = true;
        break;
      }
    }
    if (ink) {
      if (left < 0) left = x;
      right = x;
    }
  }
  if (left < 0) return work;
  final w = right - left + 1;
  final h = bottom - top + 1;
  if (w < 8 || h < 8) return work;
  return img.copyCrop(work, x: left, y: top, width: w, height: h);
}

img.Image _alignToFullWidth(
  img.Image work,
  int fullWidth, {
  required bool scaleToFill,
}) {
  final aligned = fullWidth - (fullWidth % 8);
  if (work.width == aligned) return work;
  if (scaleToFill) {
    final h = (work.height * (aligned / work.width)).round().clamp(8, 24000);
    return img.copyResize(
      work,
      width: aligned,
      height: h,
      interpolation: img.Interpolation.linear,
    );
  }
  if (work.width > aligned) {
    return img.copyCrop(work, x: 0, y: 0, width: aligned, height: work.height);
  }
  final sheet = img.Image(
    width: aligned,
    height: work.height,
    numChannels: 3,
  );
  img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(sheet, work, dstX: 0, dstY: 0);
  return sheet;
}

/// Promedio del gris (0.25R+0.5G+0.25B), tope 254. Mismo criterio que
/// el filtro 0 de las térmicas de referencia.
int _thresholdFor(img.Image work) {
  var sum = 0;
  var n = 0;
  for (var y = 0; y < work.height; y++) {
    for (var x = 0; x < work.width; x++) {
      final p = work.getPixel(x, y);
      var g = (p.r.toInt() >> 2) + (p.g.toInt() >> 1) + (p.b.toInt() >> 2);
      if (g > 249) g = 255;
      sum += g;
      n++;
    }
  }
  if (n == 0) return 254;
  final mean = sum ~/ n;
  return mean > 254 ? 254 : mean;
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

class _PrintLayout {
  const _PrintLayout({
    required this.fullWidth,
    required this.leftPad,
    required this.contentWidth,
    required this.paper,
    this.chromeFit = false,
    this.rasterScale = 1,
  });

  final int fullWidth;
  final int leftPad;
  final int contentWidth;
  final PaperWidth paper;
  final bool chromeFit;
  final int rasterScale;
}
