import 'package:flutter/material.dart';

/// Shared colors for the Pawmate hand-drawn home-journal visual language.
abstract final class PawmateColors {
  static const paper = Color(0xFFFFF8E7);
  static const ink = Color(0xFF3C3530);
  static const softBrown = Color(0xFF8B7666);
  static const rose = Color(0xFFE98B8B);
  static const lavender = Color(0xFFA99BD6);
  static const mint = Color(0xFF9BC7B0);
  static const sun = Color(0xFFF3C969);
  static const sky = Color(0xFF9DC6D8);
  static const error = Color(0xFFC96F6F);
}

/// Creates the Material theme adapted to Pawmate's paper and ink surfaces.
ThemeData buildPawmateTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: PawmateColors.rose,
        brightness: Brightness.light,
      ).copyWith(
        primary: PawmateColors.ink,
        onPrimary: PawmateColors.paper,
        secondary: PawmateColors.lavender,
        onSecondary: PawmateColors.ink,
        surface: PawmateColors.paper,
        onSurface: PawmateColors.ink,
        error: PawmateColors.error,
        onError: PawmateColors.paper,
      );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: PawmateColors.paper,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: PawmateColors.paper,
      foregroundColor: PawmateColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFFCF3),
      labelStyle: const TextStyle(color: PawmateColors.softBrown),
      hintStyle: TextStyle(color: PawmateColors.softBrown.withAlpha(170)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PawmateColors.ink, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PawmateColors.ink, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PawmateColors.lavender, width: 3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PawmateColors.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PawmateColors.error, width: 3),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: PawmateColors.ink,
      contentTextStyle: TextStyle(color: PawmateColors.paper),
    ),
  );
}
