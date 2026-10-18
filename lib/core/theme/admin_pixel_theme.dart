import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

ThemeData adminPixelTheme() {
  const square = RoundedRectangleBorder(
    side: BorderSide(color: AppColors.text, width: 2),
  );
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(color: AppColors.text, width: 1.5),
  );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryRed,
      primary: AppColors.primaryRed,
      secondary: AppColors.amber,
      surface: AppColors.panel,
      error: AppColors.statusRed,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.backgroundGray,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    dividerColor: AppColors.line,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.panel,
      foregroundColor: AppColors.text,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: AppColors.text, width: 2)),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.panel,
      elevation: 0,
      shape: square,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.panel,
      shape: square,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.statusRed, width: 2),
      ),
      prefixIconColor: AppColors.muted,
      labelStyle: TextStyle(color: AppColors.muted, fontSize: 13),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.panel,
        elevation: 0,
        shape: square,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.panel,
        shape: square,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryRed,
        shape: const RoundedRectangleBorder(),
        side: const BorderSide(color: AppColors.text, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(),
      side: const BorderSide(color: AppColors.text, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primaryRed
            : AppColors.panel,
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.panel,
      shape: square,
      elevation: 2,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.text),
      textStyle: TextStyle(color: AppColors.panel, fontSize: 12),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(AppColors.panel2),
      headingTextStyle: TextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.bold,
      ),
      dividerThickness: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: TextStyle(color: AppColors.panel),
    ),
  );
}
