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
      int? mediaHeightMils}) async {
    final profile = resolveProfile(printer, mediaId);
    final landscape = isRotated(profile, mediaWidthMils, mediaHeightMils);
    _validate(profile, printer);
    final data = await File(filePath).readAsBytes();
    final out = <int>[];
    if (data.length >= 5 &&
        ascii.decode(data.take(5).toList(), allowInvalid: true) == '%PDF-') {
      final doc = await PdfDocument.openData(data);
      try {
        if (doc.pagesCount > 200) {
          throw PrinterTransportException(
              'El PDF supera el límite de 200 etiquetas. Divídelo en archivos más pequeños.');
        }
        for (var i = 1; i <= doc.pagesCount; i++) {
          final page = await doc.getPage(i);
          try {
            final dpi = printer.dpi.value;
            final width =
                ((landscape ? profile.heightMm : profile.widthMm) * dpi / 25.4)
                    .round();
            final height =
                ((landscape ? profile.widthMm : profile.heightMm) * dpi / 25.4)
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
    final profile = printer.defaultProfile;
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
    // Receipt head widths remain the existing verified geometry. Other hardware
    // can use the other roll/head option explicitly in its own logical config.
    if (profile.widthMm * printer.dpi.dotsPerMm > printer.dotsWidth + 1) {
      throw PrinterTransportException(
          'La etiqueta supera el ancho imprimible del cabezal seleccionado. Revisa el ancho del rollo y la resolución.');
    }
  }

  @visibleForTesting
  static List<int> encodePage(
      SavedPrinter printer, PaperProfile profile, img.Image source,
      {bool landscape = false}) {
    _validate(profile, printer);
    if (landscape) source = img.copyRotate(source, angle: 90);
    final dpm = printer.dpi.dotsPerMm;
    final exactWidth = (profile.widthMm * dpm).round();
    // Pad the final byte; do not truncate the right edge of the label.
    final width = ((exactWidth + 7) ~/ 8) * 8;
    final height = (profile.heightMm * dpm).round();
    final page = img.Image(width: width, height: height);
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
        final v = luminance < 180 ? 0 : 255;
        page.setPixelRgb(xx, yy, v, v, v);
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
            'OFFSET 0 mm\r\nCLS\r\nBITMAP 0,0,${width ~/ 8},$height,0,'),
        ...raster,
        ...ascii.encode('\r\nPRINT 1,1\r\n')
      ];
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
