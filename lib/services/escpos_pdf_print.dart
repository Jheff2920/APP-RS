import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';

import '../models/paper_width.dart';
import '../models/saved_printer.dart';
import 'escpos_feed.dart';
import 'escpos_gs_v0.dart';

class EscPosPdfPrint {
  /// Rasteriza PDF como imagen térmica (estilo apps tipo RawBT).
  /// El trabajo pesado de imagen va en un isolate para no congelar la UI.
  static Future<List<int>> build(
    SavedPrinter printer, {
    required String filePath,
    int maxPages = 8,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('No se encontro el archivo: $filePath');
    }

    final profile = await CapabilityProfile.load();
    final paperSize =
        printer.paper == PaperWidth.mm58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paperSize, profile);
    final layout = _layout(printer);

    // openData evita cuelgues de openFile con paths del PrintService/cache.
    final raw = await file.readAsBytes();
    final doc = await PdfDocument.openData(raw).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Tiempo agotado abriendo el PDF'),
    );
    try {
      final bytes = <int>[...generator.reset()];

      final pages = math.min(doc.pagesCount, maxPages);
      for (var i = 1; i <= pages; i++) {
        final page = await doc.getPage(i);
        try {
          final png = await _renderPagePng(page, layout);
          if (png == null) continue;

          final band = await Isolate.run(
            () => _encodePngToGsV0(
              pngBytes: png,
              fullWidth: layout.fullWidth,
              leftPad: layout.leftPad,
              contentWidth: layout.contentWidth,
            ),
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
      return bytes;
    } finally {
      await doc.close();
    }
  }

  static Future<List<int>> buildImageFile(
    SavedPrinter printer, {
    required String filePath,
  }) async {
    final data = await File(filePath).readAsBytes();
    final layout = _layout(printer);

    final body = await Isolate.run(
      () => _encodePngToGsV0(
        pngBytes: data,
        fullWidth: layout.fullWidth,
        leftPad: layout.leftPad,
        contentWidth: layout.contentWidth,
      ),
    );
    if (body.isEmpty) {
      throw Exception('No se pudo leer la imagen');
    }

    final profile = await CapabilityProfile.load();
    final paperSize =
        printer.paper == PaperWidth.mm58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paperSize, profile);

    return <int>[
      ...generator.reset(),
      ...body,
      ...EscPosFeed.finishJob(
        bottomMm: printer.margins.bottomMm,
        paperDotsWidth: layout.fullWidth,
        cut: printer.cut,
      ),
    ];
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
    final pageImage = await page.render(
      width: renderWidth,
      height: renderHeight,
      format: PdfPageImageFormat.png,
      backgroundColor: '#FFFFFFFF',
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Tiempo agotado rasterizando el PDF'),
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
    fullWidth: fullWidth,
    leftPad: leftPad,
    contentWidth: contentWidth,
  );
  if (prepared == null) return const [];
  return EscPosGsV0.encode(prepared);
}

img.Image? _prepareBitmap(
  List<int> bytes, {
  required int fullWidth,
  required int leftPad,
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

  _simpleThreshold(work);
  work = _trimTopBottomWhite(work);

  if (work.width % 8 != 0) {
    final w = work.width - (work.width % 8);
    if (w < 8) return null;
    work = img.copyCrop(work, x: 0, y: 0, width: w, height: work.height);
  }

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

  if (leftPad == 0 && contentWidth == fullWidth) {
    return work;
  }

  final sheet = img.Image(
    width: fullWidth,
    height: work.height,
    numChannels: 3,
  );
  img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(sheet, work, dstX: leftPad, dstY: 0);
  return sheet;
}

img.Image _trimTopBottomWhite(img.Image image, {int inkBelow = 128}) {
  var top = 0;
  while (top < image.height && _rowIsWhite(image, top, inkBelow)) {
    top++;
  }
  var bottom = image.height - 1;
  while (bottom > top && _rowIsWhite(image, bottom, inkBelow)) {
    bottom--;
  }
  final h = bottom - top + 1;
  if (h < 8 || (top == 0 && bottom == image.height - 1)) {
    return image;
  }
  return img.copyCrop(image, x: 0, y: top, width: image.width, height: h);
}

bool _rowIsWhite(img.Image image, int y, int inkBelow) {
  for (var x = 0; x < image.width; x++) {
    if (image.getPixel(x, y).r < inkBelow) return false;
  }
  return true;
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

void _simpleThreshold(img.Image work) {
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

  for (var y = 0; y < work.height; y++) {
    for (var x = 0; x < work.width; x++) {
      final p = work.getPixel(x, y);
      final lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
      if (lum > threshold) {
        work.setPixelRgb(x, y, 255, 255, 255);
      } else {
        work.setPixelRgb(x, y, 0, 0, 0);
      }
    }
  }
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
