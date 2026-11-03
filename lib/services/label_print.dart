import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';

import '../models/saved_printer.dart';
import 'escpos_gs_v0.dart';
import 'transports/printer_transport.dart';

/// Fixed-size pages. Never trims white space or uses receipt feed/cut/ads.
class LabelPrint {
  static const maxJobBytes = 32 * 1024 * 1024;
  static PaperProfile resolveProfile(SavedPrinter printer, String? mediaId) {
    final profiles = printer.enabledProfiles;
    if (profiles.isEmpty) {
      throw PrinterTransportException('Habilita un tamaño de etiqueta.');
    }
    if (mediaId == null || mediaId.isEmpty) return printer.defaultProfile;
    for (final profile in profiles) {
      if (profile.mediaId == mediaId) return profile;
    }
    throw PrinterTransportException(
        'El tamaño elegido ya no está disponible en esta impresora. Vuelve a seleccionarlo.');
  }

  static Future<List<int>> build(SavedPrinter printer,
      {required String filePath,
      String? mediaId,
      int? mediaWidthMils,
      int? mediaHeightMils,
      int? firstPage,
      int? lastPage}) async {
    final profile = resolveProfile(printer, mediaId);
    final landscape = isRotated(profile, mediaWidthMils, mediaHeightMils);
    // Render the page in the shape it will have once turned onto the label.
    final sideways = ((landscape ? 90 : 0) + profile.rotation) % 180 != 0;
    _validate(profile, printer);
    final data = await File(filePath).readAsBytes();
    final out = <int>[];
    if (data.length >= 5 &&
        ascii.decode(data.take(5).toList(), allowInvalid: true) == '%PDF-') {
      final doc = await PdfDocument.openData(data);
      try {
        final first = (firstPage ?? 1).clamp(1, doc.pagesCount);
        final last = (lastPage ?? doc.pagesCount).clamp(first, doc.pagesCount);
        if (last - first + 1 > 200) {
          throw PrinterTransportException(
              'El PDF supera el límite de 200 etiquetas. Divídelo en archivos más pequeños.');
        }
        for (var i = first; i <= last; i++) {
          final page = await doc.getPage(i);
          try {
            final dpi = printer.dpi.value;
            final width =
                ((sideways ? profile.heightMm : profile.widthMm) * dpi / 25.4)
                    .round();
            final height =
                ((sideways ? profile.widthMm : profile.heightMm) * dpi / 25.4)
                    .round();
            final ratio = math.min(width / page.width, height / page.height);
            final rendered = await page.render(
                width: math.max(1, page.width * ratio),
                height: math.max(1, page.height * ratio),
                format: PdfPageImageFormat.png,
                backgroundColor: '#FFFFFF');
            if (rendered == null) {
              throw PrinterTransportException('No se pudo leer la página $i.');
            }
            out.addAll(await _encodeAsync(
                printer, profile, rendered.bytes, landscape));
            if (out.length > maxJobBytes) {
              throw PrinterTransportException(
                  'El archivo de etiquetas es demasiado grande. Divídelo en varios trabajos.');
            }
          } finally {
            await page.close();
          }
        }
      } finally {
        await doc.close();
      }
    } else {
      out.addAll(await _encodeAsync(printer, profile, data, landscape));
    }
    return out;
  }

  static bool isRotated(
          PaperProfile profile, int? widthMils, int? heightMils) =>
      widthMils != null &&
      heightMils != null &&
      widthMils > 0 &&
      heightMils > 0 &&
      profile.widthMm != profile.heightMm &&
      (widthMils > heightMils) != (profile.widthMm > profile.heightMm);

  static Future<List<int>> _encodeAsync(SavedPrinter p, PaperProfile profile,
          Uint8List bytes, bool landscape) =>
      compute((Map<String, dynamic> args) {
        final image = img.decodeImage(args['bytes'] as Uint8List);
        if (image == null) {
          throw PrinterTransportException(
              'Usa un PDF o una imagen para imprimir etiquetas.');
        }
        return encodePage(
            SavedPrinter.fromJson(args['printer'] as Map<String, dynamic>),
            PaperProfile.fromJson(args['profile'] as Map<String, dynamic>),
            image,
            landscape: args['landscape'] as bool);
      }, {
        'printer': p.toJson(),
        'profile': profile.toJson(),
        'bytes': bytes,
        'landscape': landscape
      });

  static Future<List<int>> testPage(SavedPrinter printer) async {
    final profile = resolveProfile(printer, null);
    _validate(profile, printer);
    final width = (profile.widthMm * printer.dpi.dotsPerMm).round();
    final height = (profile.heightMm * printer.dpi.dotsPerMm).round();
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    final ink = img.ColorRgb8(0, 0, 0);
    final inset = math.min(12, math.min(width, height) ~/ 8);
    img.drawRect(image,
        x1: inset,
        y1: inset,
        x2: width - inset - 1,
        y2: height - inset - 1,
        color: ink,
        thickness: 2);
    img.drawString(image, 'RED SOLUCIONES',
        font: img.arial14, x: inset + 6, y: inset + 6, color: ink);
    img.drawString(image, '${profile.widthMm} x ${profile.heightMm} mm',
        font: img.arial14, x: inset + 6, y: inset + 28, color: ink);
    return encodePage(printer, profile, image);
  }

  static void _validate(PaperProfile profile, SavedPrinter printer) {
    final error = profile.validationError;
    if (error != null) throw PrinterTransportException(error);
    // A label wider than the head (50 mm on a 48 mm head) is fine: encodePage
    // prints its centre. Only a label wider than the roll cannot fit.
    if (profile.widthMm > printer.paper.rollWidthMm) {
      throw PrinterTransportException(
          'La etiqueta es más ancha que el rollo de la impresora. Revisa el ancho del rollo.');
    }
  }

  @visibleForTesting
  static List<int> encodePage(
      SavedPrinter printer, PaperProfile profile, img.Image source,
      {bool landscape = false}) {
    _validate(profile, printer);
    final angle = ((landscape ? 90 : 0) + profile.rotation) % 360;
    if (angle != 0) source = img.copyRotate(source, angle: angle);
    final dpm = printer.dpi.dotsPerMm;
    final exactWidth = (profile.widthMm * dpm).round();
    // Pad the final byte; do not truncate the right edge of the label.
    final width = ((exactWidth + 7) ~/ 8) * 8;
    final height = (profile.heightMm * dpm).round();
    var page = img.Image(width: width, height: height);
    img.fill(page, color: img.ColorRgb8(255, 255, 255));
    final usableW =
        ((profile.widthMm - profile.leftMm - profile.rightMm) * dpm).round();
    final usableH =
        ((profile.heightMm - profile.topMm - profile.bottomMm) * dpm).round();
    final scale = math.min(usableW / source.width, usableH / source.height) *
        profile.scalePercent /
        100;
    final resized = img.copyResize(source,
        width: math.max(1, (source.width * scale).round()),
        height: math.max(1, (source.height * scale).round()),
        interpolation: img.Interpolation.cubic);
    final x0 = ((profile.leftMm + profile.offsetXmm) * dpm).round();
    final y0 = ((profile.topMm + profile.offsetYmm) * dpm).round();
    // Darker settings also turn light greys (thin, anti-aliased text) into ink:
    // 180 at the middle (8), 222 at 15. 0 keeps the original 180.
    final ink = profile.darkness == 0 ? 180 : 180 + (profile.darkness - 8) * 6;
    for (var y = 0; y < resized.height; y++) {
      final yy = y0 + y;
      if (yy < 0 || yy >= height) continue;
      for (var x = 0; x < resized.width; x++) {
        final xx = x0 + x;
        if (xx < 0 || xx >= exactWidth) continue;
        final pixel = resized.getPixel(x, y);
        final a = pixel.aNormalized;
        final luminance =
            (pixel.r * .299 + pixel.g * .587 + pixel.b * .114) * a +
                255 * (1 - a);
        // The page starts white, so only ink is drawn; that keeps the extra
        // dots of [thicken] from being whitened by the pixels that follow.
        if (luminance >= ink) continue;
        final grow = profile.thicken ? 1 : 0;
        for (var dy = 0; dy <= grow && yy + dy < height; dy++) {
          for (var dx = 0; dx <= grow && xx + dx < exactWidth; dx++) {
            page.setPixelRgb(xx + dx, yy + dy, 0, 0, 0);
          }
        }
      }
    }
    if (printer.protocol == PrinterProtocol.tspl) {
      final raster = <int>[];
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x += 8) {
          var value = 0;
          for (var bit = 0; bit < 8; bit++) {
            // TSPL bitmap: zero is ink, one is white.
            if (page.getPixel(x + bit, y).r >= 128) value |= 0x80 >> bit;
          }
          raster.add(value);
        }
      }
      return [
        ...ascii.encode('SIZE ${profile.widthMm} mm,${profile.heightMm} mm\r\n'
            'GAP ${profile.gapMm} mm,0 mm\r\nDIRECTION 1\r\nREFERENCE 0,0\r\n'
            'OFFSET 0 mm\r\n'
            '${profile.darkness > 0 ? 'DENSITY ${profile.darkness}\r\n' : ''}'
            'CLS\r\nBITMAP 0,0,${width ~/ 8},$height,0,'),
        ...raster,
        ...ascii.encode('\r\nPRINT 1,1\r\n')
      ];
    }
    // The head is centred over the roll; a raster wider than the head prints
    // garbled on ESC/POS, so send only the strip the head can reach.
    final head = printer.dotsWidth;
    if (width > head) {
      page = img.copyCrop(page,
          x: math.max(0, (exactWidth - head) ~/ 2),
          y: 0,
          width: head,
          height: height);
    }
    final gapDots = (profile.gapMm * dpm).round();
    final feed = <int>[];
    for (var remaining = gapDots; remaining > 0;) {
      final count = math.min(255, remaining);
      feed.addAll([0x1b, 0x4a, count]);
      remaining -= count;
    }
    return [0x1b, 0x40, ...EscPosGsV0.encode(page), ...feed];
  }
}
