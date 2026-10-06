import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Verde profundo de terminal POS: hardware profesional de caja, no app genérica.
const _brand = Color(0xFF195C4B);
const _brandContainer = Color(0xFFCCEBE1);
const _onBrandContainer = Color(0xFF00201A);
const _surface = Color(0xFFF5F7F6);
const _surfaceVariant = Color(0xFFE2EDEA);
const _outline = Color(0xFF8FADA7);

final ThemeData boletaPrintTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: _brand,
    onPrimary: Colors.white,
    primaryContainer: _brandContainer,
    onPrimaryContainer: _onBrandContainer,
    secondary: Color(0xFF4C6B64),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFCEE8E0),
    onSecondaryContainer: Color(0xFF07201B),
    surface: _surface,
    onSurface: Color(0xFF191C1B),
    onSurfaceVariant: Color(0xFF3F4946),
    surfaceContainerHighest: _surfaceVariant,
    outline: _outline,
    outlineVariant: Color(0xFFBFD0CB),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    shadow: Colors.black,
    scrim: Colors.black,
  ),
  // Un solo momento de identidad: la AppBar usa el verde de marca.
  appBarTheme: const AppBarTheme(
    backgroundColor: _brand,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 2,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    iconTheme: IconThemeData(color: Colors.white),
    actionsIconTheme: IconThemeData(color: Colors.white),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      side: BorderSide(color: Color(0xFFD8E8E4), width: 1),
    ),
    margin: EdgeInsets.zero,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _brand,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _brand,
      side: const BorderSide(color: _brand),
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: _brand),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: _brand,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFBFD0CB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFBFD0CB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _brand, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: _surfaceVariant,
    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    side: BorderSide.none,
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFFD8E8E4),
    thickness: 1,
    space: 1,
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  ),
  splashFactory: InkRipple.splashFactory,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    },
  ),
);
