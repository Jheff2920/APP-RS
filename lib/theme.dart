import 'package:flutter/material.dart';

/// Tema pensado para tablets POS antiguas: splash y transiciones baratas.
final ThemeData boletaPrintTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    },
  ),
);
