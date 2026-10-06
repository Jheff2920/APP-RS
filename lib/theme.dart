import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Morado profundo del logo de Red Soluciones — identidad de marca real.
const _brand = Color(0xFF2B0A53);
const _brandMid = Color(0xFF5B3A8E);
const _brandContainer = Color(0xFFEDE9F6);
const _onBrandContainer = Color(0xFF1A0036);
const _background = Color(0xFFF5F3F9);
const _paper = Colors.white;
const _ink = Color(0xFF1C1530);
const _inkSoft = Color(0xFF5A5070);
const _line = Color(0xFFE6E0F0);
const _outline = Color(0xFFC9BEDB);

/// Colores de estado fuera del ColorScheme.
class AppColors {
  static const brand = _brand;
  static const background = _background;
  static const paper = _paper;
  static const ink = _ink;
  static const inkSoft = _inkSoft;
  static const line = _line;
  static const ok = Color(0xFF1B7F5A);
  static const okSoft = Color(0xFFE3F3EC);
  static const warn = Color(0xFF9A5B00);
  static const warnSoft = Color(0xFFFFF1DC);
  static const bluetooth = Color(0xFF1565C0);
  static const usb = Color(0xFFBF360C);
}

final _radius12 = BorderRadius.circular(12);

final ThemeData boletaPrintTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: _brand,
    onPrimary: Colors.white,
    primaryContainer: _brandContainer,
    onPrimaryContainer: _onBrandContainer,
    secondary: _brandMid,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE6DDF7),
    onSecondaryContainer: Color(0xFF21005D),
    surface: _paper,
    onSurface: _ink,
    onSurfaceVariant: _inkSoft,
    surfaceContainerLowest: _paper,
    surfaceContainerLow: Color(0xFFFAF8FD),
    surfaceContainer: _background,
    surfaceContainerHigh: Color(0xFFEFEBF6),
    surfaceContainerHighest: Color(0xFFE9E4F2),
    outline: _outline,
    outlineVariant: _line,
    error: Color(0xFFB3261E),
    onError: Colors.white,
    errorContainer: Color(0xFFFCE4E2),
    onErrorContainer: Color(0xFF410002),
    shadow: Colors.black,
    scrim: Colors.black,
  ),
  scaffoldBackgroundColor: _background,
  appBarTheme: const AppBarTheme(
    backgroundColor: _brand,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 19,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    iconTheme: IconThemeData(color: Colors.white),
    actionsIconTheme: IconThemeData(color: Colors.white),
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      height: 1.2,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 16, height: 1.4),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45),
    bodySmall: TextStyle(fontSize: 12.5, height: 1.4),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  ),
  cardTheme: const CardThemeData(
    elevation: 0,
    color: _paper,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(color: _line),
    ),
    margin: EdgeInsets.zero,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: _radius12),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _brand,
      backgroundColor: _paper,
      side: const BorderSide(color: _outline),
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: _radius12),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _brand,
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(borderRadius: _radius12),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: _brand,
    foregroundColor: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
    ),
    extendedTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _paper,
    border: OutlineInputBorder(
      borderRadius: _radius12,
      borderSide: const BorderSide(color: _outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: _radius12,
      borderSide: const BorderSide(color: _outline),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: _radius12,
      borderSide: const BorderSide(color: _line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: _radius12,
      borderSide: const BorderSide(color: _brand, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: _radius12,
      borderSide: const BorderSide(color: Color(0xFFB3261E)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: _radius12,
      borderSide: const BorderSide(color: Color(0xFFB3261E), width: 2),
    ),
    labelStyle: const TextStyle(color: _inkSoft),
    helperStyle: const TextStyle(color: _inkSoft, fontSize: 12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: _radius12),
      ),
      side: const WidgetStatePropertyAll(BorderSide(color: _outline)),
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? _brand : _paper,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : _ink,
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : _inkSoft,
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? Colors.white : _outline,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? _brand : _background,
    ),
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? _brand : _outline,
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: _paper,
    selectedColor: _brandContainer,
    labelStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _ink,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    side: const BorderSide(color: _outline),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  ),
  dividerTheme: const DividerThemeData(color: _line, thickness: 1, space: 1),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    iconColor: _inkSoft,
    titleTextStyle: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: _ink,
    ),
    subtitleTextStyle: TextStyle(fontSize: 13, color: _inkSoft, height: 1.35),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: _paper,
    surfaceTintColor: Colors.transparent,
    elevation: 6,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 15, color: _ink),
  ),
  menuTheme: MenuThemeData(
    style: MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(_paper),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  ),
  dropdownMenuTheme: DropdownMenuThemeData(
    menuStyle: MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(_paper),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: _paper,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    dragHandleColor: _outline,
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    backgroundColor: _paper,
    surfaceTintColor: Colors.transparent,
    elevation: 4,
    titleTextStyle: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: _ink,
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: _radius12),
    backgroundColor: _ink,
    contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: _brand),
  splashFactory: InkRipple.splashFactory,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    },
  ),
);
