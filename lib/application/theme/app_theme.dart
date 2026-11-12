import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFFB9E2DB);
  static const navy = Color(0xFF0D1F43);
  static const green = Color(0xFF01D0AF);
  static const inputFill = Color(0xFFD9D9D9);
  static const displayFontFamily = 'Crushed';
  static final _baseTextTheme = ThemeData(useMaterial3: true).textTheme;

  static final _titleTextTheme = _baseTextTheme.copyWith(
    displayLarge: _baseTextTheme.displayLarge?.copyWith(
      fontFamily: displayFontFamily,
    ),
    displayMedium: _baseTextTheme.displayMedium?.copyWith(
      fontFamily: displayFontFamily,
    ),
    displaySmall: _baseTextTheme.displaySmall?.copyWith(
      fontFamily: displayFontFamily,
    ),
    headlineLarge: _baseTextTheme.headlineLarge?.copyWith(
      fontFamily: displayFontFamily,
    ),
    headlineMedium: _baseTextTheme.headlineMedium?.copyWith(
      fontFamily: displayFontFamily,
    ),
    headlineSmall: _baseTextTheme.headlineSmall?.copyWith(
      fontFamily: displayFontFamily,
    ),
    titleLarge: _baseTextTheme.titleLarge?.copyWith(
      fontFamily: displayFontFamily,
    ),
    titleMedium: _baseTextTheme.titleMedium?.copyWith(
      fontFamily: displayFontFamily,
    ),
    titleSmall: _baseTextTheme.titleSmall?.copyWith(
      fontFamily: displayFontFamily,
    ),
  );

  static final ThemeData auth = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: navy,
          brightness: Brightness.light,
        ).copyWith(
          primary: green,
          onPrimary: Colors.white,
          secondary: navy,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: navy,
        ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: navy,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontFamily: displayFontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: _titleTextTheme,
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      hintStyle: const TextStyle(color: Colors.black54),
      labelStyle: const TextStyle(color: navy),
      floatingLabelStyle: const TextStyle(color: navy),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: green, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: green,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: navy,
        minimumSize: const Size(64, 48),
        side: const BorderSide(color: navy),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        color: navy,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: displayFontFamily,
      ),
      contentTextStyle: const TextStyle(color: navy, fontSize: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: navy,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? green : navy,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: navy),
  );
}
