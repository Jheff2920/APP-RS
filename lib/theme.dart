import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Morado profundo del logo de Red Soluciones — identidad de marca real.
const _brand = Color(0xFF2B0A53);
const _brandMid = Color(0xFF6B3FA0);
const _brandContainer = Color(0xFFEDE9F6);
const _onBrandContainer = Color(0xFF1A0036);
const _surface = Color(0xFFFAFAFA);
const _surfaceVariant = Color(0xFFF2EEF9);
const _outline = Color(0xFFC5B8DA);

final ThemeData boletaPrintTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: _brand,
    onPrimary: Colors.white,
    primaryContainer: _brandContainer,
    onPrimaryContainer: _onBrandContainer,
    secondary: _brandMid,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE8DEFF),
    onSecondaryContainer: Color(0xFF21005D),
    surface: _surface,
    onSurface: Color(0xFF1A1A2E),
    onSurfaceVariant: Color(0xFF4A3F5C),
    surfaceContainerHighest: _surfaceVariant,
    outline: _outline,
    outlineVariant: Color(0xFFDDD6EC),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    shadow: Colors.black,
    scrim: Colors.black,
  ),
  scaffoldBackgroundColor: _surface,
  // Un solo momento de identidad: AppBar con el morado del logo.
  appBarTheme: const AppBarTheme(
    backgroundColor: _brand,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    iconTheme: IconThemeData(color: Colors.white),
    actionsIconTheme: IconThemeData(color: Colors.white),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(color: Color(0xFFE8E0F4), width: 1),
    ),
    margin: EdgeInsets.zero,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _brand,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _brand,
      side: const BorderSide(color: _brand, width: 1.5),
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: _brand),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: _brand,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
    ),
    extendedTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _brand, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
    ),
    labelStyle: const TextStyle(color: Color(0xFF4A3F5C)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: _surfaceVariant,
    labelStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: _onBrandContainer,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    side: BorderSide.none,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFFEDE9F6),
    thickness: 1,
    space: 1,
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: Colors.white,
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: Colors.white,
    elevation: 4,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    backgroundColor: const Color(0xFF1A1A2E),
    contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
  ),
  splashFactory: InkRipple.splashFactory,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    },
  ),
);
