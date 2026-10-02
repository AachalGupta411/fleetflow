import 'package:flutter/material.dart';

class AppColors {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color navyDeep = Color(0xFF071526);
  static const Color blue = Color(0xFF2563EB);
  static const Color cyan = Color(0xFF1AA6B7);
  static const Color surface = Color(0xFF10141C);
  static const Color card = Color(0xFF1E2531);
  static const Color panel = Color(0xFF171C26);
  static const Color line = Color(0xFF2C3544);
  static const Color ink = Color(0xFFF5F7FB);
  static const Color muted = Color(0xFF9AA6B8);
  static const Color success = Color(0xFF4ADE80);
  static const Color danger = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
}

ThemeData buildAppTheme() {
  const text = AppColors.ink;
  final colorScheme = ColorScheme.dark(
    primary: AppColors.blue,
    onPrimary: Colors.white,
    secondary: AppColors.cyan,
    onSecondary: Colors.white,
    surface: AppColors.card,
    onSurface: text,
    error: AppColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.panel,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel,
      labelStyle: const TextStyle(color: AppColors.muted),
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.blue),
      ),
    ),
    textTheme: Typography.material2021().white.apply(
      bodyColor: text,
      displayColor: text,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: text,
      iconColor: AppColors.muted,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.blue,
      labelStyle: const TextStyle(color: text),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.card),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.blue,
      foregroundColor: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: const BorderSide(color: AppColors.line),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0xFFBFDBFE)),
    ),
  );
}
