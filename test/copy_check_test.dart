import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hello_world_app/l10n/app_lang.dart';
import 'package:hello_world_app/legal/legal_copy.dart';
import 'package:hello_world_app/services/user_error.dart';

/// Los textos de la app son para quien la usa: sin nombres de librerías,
/// ids internos ni palabras en español sin tilde.
void main() {
  // Términos técnicos que no deben verse en textos legales ni de ayuda.
  final technical = <String, RegExp>{
    'in_app_purchase': RegExp(r'in_app_purchase'),
    'url_launcher': RegExp(r'url_launcher'),
    'SharedPreferences': RegExp(r'SharedPreferences'),
    'esc_pos': RegExp(r'esc_pos|print_bluetooth|pdfx'),
    'puerto TCP': RegExp(r':9100|TCP'),
    'ESC/POS': RegExp(r'ESC/POS|raster', caseSensitive: false),
    'SDK': RegExp(r'\bSDKs?\b'),
    'id de producto': RegExp(r'redpos_[a-z_]+monthly|productId'),
    'variable': RegExp(r'\$\{|\$[a-zA-Z]'),
    'equipo concreto': RegExp(r'\bIMIN\b|\bChrome\b'),
    'config. de compilación': RegExp(r'compilación|build time|API base'),
  };

  List<LegalSection> allLegal(L l) => [
        ...LegalCopy.terms(l),
        ...LegalCopy.privacy(l),
        ...LegalCopy.privacySummary(l),
        LegalCopy.thirdParties(l),
      ];

  for (final english in [false, true]) {
    final lang = english ? 'inglés' : 'español';

    test('textos legales ($lang): sin nombres de código ni variables', () {
      final l = L(english);
      final problems = <String>[];
      for (final s in allLegal(l)) {
        for (final e in technical.entries) {
          if (e.value.hasMatch(s.title) || e.value.hasMatch(s.body)) {
            problems.add('«${s.title}» menciona ${e.key}');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('textos legales ($lang): conservan lo que exige Play', () {
      final l = L(english);
      final text = allLegal(l).map((s) => '${s.title}\n${s.body}').join('\n');
      for (final needle in [
        'Google Play',
        'Firebase',
        'AdMob',
        'Red Soluciones',
        'jcefe.2920@gmail.com',
      ]) {
        expect(text, contains(needle), reason: 'falta «$needle»');
      }
      // Debe seguir diciendo que no se sube el contenido a RedPOS.
      expect(
        text.toLowerCase(),
        contains(english ? 'do not upload' : 'no subimos'),
      );
    });
  }

  test('friendlyError oculta prefijos y errores técnicos', () {
    expect(friendlyError(Exception('Se perdió la conexión')),
        'Se perdió la conexión');
    final generic = friendlyError(StateError('Null check operator used'));
    expect(generic, isNot(contains('Null')));
    expect(generic, isNot(contains('StateError')));
    expect(friendlyError(const FormatException('x')), isNot(contains('Format')));
    expect(friendlyError(TypeError()), isNotEmpty);
  });

  // Palabras en español que siempre llevan tilde (o ñ).
  final noAccent = RegExp(
    r'\b(conexion|direccion|configuracion|impresion|seleccion|informacion|'
    r'ubicacion|aplicacion|funcion|opcion|numero|codigo|pagina|telefono|'
    r'tambien|despues|vacio|vacia|valido|concedelos|activalo|aparato)\b',
    caseSensitive: false,
  );

  // Estos archivos arman texto que sale impreso en papel: la impresora
  // térmica puede no tener las tildes, así que allí no se exigen.
  const printedText = {
    'escpos_test_page.dart',
    'sunat_escpos_print.dart',
    'custom_ticket_escpos.dart',
    'redpos_ad_escpos.dart',
    'escpos_capability_profile.dart',
  };

  test('el texto de la interfaz tiene tildes', () {
    final problems = <String>[];
    final literal = RegExp(r"'(?:[^'\\\n]|\\.)*'|" r'"(?:[^"\\\n]|\\.)*"');
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      if (printedText.contains(name)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//') || line.startsWith('import ')) continue;
        for (final m in literal.allMatches(line)) {
          final text = m.group(0)!;
          // Rutas y claves internas no cuentan.
          if (text.contains('/') && !text.contains(' ')) continue;
          final hit = noAccent.firstMatch(text);
          if (hit != null) {
            problems.add('${file.path}:${i + 1}  «${hit.group(0)}»');
          }
        }
      }
    }
    expect(problems, isEmpty, reason: '\n${problems.join('\n')}');
  });
}
