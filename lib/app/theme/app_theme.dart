import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const seedColor = Color(0xFF1A237E);
    const secondary = Color(0xFFB93815);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: seedColor,
          onPrimary: Colors.white,
          secondary: secondary,
          onSecondary: Colors.white,
          tertiary: const Color(0xFF5C1800),
          onTertiary: Colors.white,
          surface: const Color(0xFFFBF8FF),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      navigationBarTheme: _navigationBarTheme(colorScheme),
      iconButtonTheme: _iconButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      scaffoldBackgroundColor: const Color(0xFFF5F2FB),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFC6C5D4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF767683)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF767683)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: seedColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  static ThemeData dark() {
    const seedColor = Color(0xFFBDC2FF);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: seedColor,
          secondary: const Color(0xFFFFB5A0),
          tertiary: const Color(0xFFFFB59D),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      navigationBarTheme: _navigationBarTheme(colorScheme),
      iconButtonTheme: _iconButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111827),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF243042)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: seedColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  static IconButtonThemeData _iconButtonTheme() => IconButtonThemeData(
    style: IconButton.styleFrom(minimumSize: const Size.square(48)),
  );

  static NavigationBarThemeData _navigationBarTheme(ColorScheme colorScheme) =>
      NavigationBarThemeData(
        height: 80,
        indicatorColor: colorScheme.secondary,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? colorScheme.onSecondary
              : colorScheme.onSurfaceVariant;
          return IconThemeData(color: color, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      );

  static FilledButtonThemeData _filledButtonTheme() => FilledButtonThemeData(
    style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
  );

  static OutlinedButtonThemeData _outlinedButtonTheme() =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      );

  static TextButtonThemeData _textButtonTheme() => TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
  );
}
