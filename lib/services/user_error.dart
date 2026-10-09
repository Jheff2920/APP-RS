import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../l10n/app_lang.dart';

/// Texto de error para mostrar al usuario: sin prefijos como «Exception:»,
/// nombres de clases, rutas ni trazas. Si el mensaje parece técnico, devuelve
/// uno genérico.
String friendlyError(Object error) {
  final generic = tr(
    'Ocurrió un error inesperado. Inténtalo de nuevo.',
    'Something went wrong. Please try again.',
  );
  if (error is TimeoutException) {
    return tr(
      'Se agotó el tiempo de espera. Inténtalo de nuevo.',
      'The request timed out. Please try again.',
    );
  }
  if (error is FileSystemException) {
    return tr('No se pudo leer el archivo.', 'Could not read the file.');
  }
  if (error is MissingPluginException) return generic;

  var text = error is PlatformException
      ? (error.message ?? '')
      : error.toString();
  text = text
      .replaceFirst(
        RegExp(r'^(Exception|Error|Bad state|Invalid argument\(s\)):\s*'),
        '',
      )
      .trim();
  if (text.isEmpty || _looksTechnical(text)) return generic;
  return text;
}

final _technical = RegExp(
  r'(Exception|Error\b|Instance of|is not a subtype|type .* is not|'
  r'Null check|NoSuchMethod|PlatformException|\bnull\b|package:|dart:|'
  r'\.dart\b|#\d+\s)',
);

bool _looksTechnical(String text) => _technical.hasMatch(text);
