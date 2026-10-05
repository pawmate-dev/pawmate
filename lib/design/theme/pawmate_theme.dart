import 'package:flutter/material.dart';

import 'colors.dart';

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
      surfaceTintColor: Colors.transparent,
      foregroundColor: PawmateColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PawmateColors.card,
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
