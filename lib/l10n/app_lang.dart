import 'package:flutter/widgets.dart';

/// English for every non-Spanish device language (US, etc.).
bool get isAppEnglish {
  try {
    return WidgetsBinding.instance.platformDispatcher.locale.languageCode !=
        'es';
  } catch (_) {
    return false;
  }
}

/// UI copy: `l('Español', 'English')`.
class L {
  const L(this.english);
  final bool english;

  factory L.of(BuildContext context) {
    return L(Localizations.localeOf(context).languageCode != 'es');
  }

  String call(String es, String en) => english ? en : es;
}

String tr(String es, String en) => isAppEnglish ? en : es;
