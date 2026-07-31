import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light tema açık renk şeması ve bileşen temaları üretir', () {
      final theme = AppTheme.light();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, const Color(0xFF1A237E));
      expect(theme.colorScheme.onPrimary, Colors.white);
      expect(theme.colorScheme.secondary, const Color(0xFFB93815));
      expect(theme.colorScheme.surface, const Color(0xFFFBF8FF));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F2FB));
      expect(theme.appBarTheme.centerTitle, isFalse);
      expect(theme.appBarTheme.backgroundColor, Colors.transparent);
      expect(theme.cardTheme.color, Colors.white);
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.inputDecorationTheme.fillColor, Colors.white);
      expect(theme.navigationBarTheme.height, 80);
      expect(
        theme.navigationBarTheme.indicatorColor,
        theme.colorScheme.secondary,
      );
      expect(
        theme.navigationBarTheme.labelBehavior,
        NavigationDestinationLabelBehavior.alwaysShow,
      );
    });

    test('dark tema koyu renk şeması ve bileşen temaları üretir', () {
      final theme = AppTheme.dark();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, const Color(0xFFBDC2FF));
      expect(theme.colorScheme.secondary, const Color(0xFFFFB5A0));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0F172A));
      expect(theme.cardTheme.color, const Color(0xFF111827));
      expect(theme.inputDecorationTheme.fillColor, const Color(0xFF111827));
      expect(theme.navigationBarTheme.height, 80);
    });

    test(
      'navigationBar icon/label temaları seçili ve seçili olmayan durumları ayırır',
      () {
        for (final theme in [AppTheme.light(), AppTheme.dark()]) {
          final iconTheme = theme.navigationBarTheme.iconTheme;
          final labelTheme = theme.navigationBarTheme.labelTextStyle;
          expect(iconTheme, isNotNull);
          expect(labelTheme, isNotNull);

          final selectedIcon = iconTheme!.resolve({WidgetState.selected});
          final unselectedIcon = iconTheme.resolve(<WidgetState>{});
          expect(selectedIcon?.color, theme.colorScheme.onSecondary);
          expect(unselectedIcon?.color, theme.colorScheme.onSurfaceVariant);

          final selectedLabel = labelTheme!.resolve({WidgetState.selected});
          final unselectedLabel = labelTheme.resolve(<WidgetState>{});
          expect(selectedLabel?.fontWeight, FontWeight.w700);
          expect(unselectedLabel?.fontWeight, FontWeight.w500);
        }
      },
    );

    test('buton temaları minimum dokunma boyutunu garanti eder', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        expect(
          theme.filledButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
          const Size(48, 48),
        );
        expect(
          theme.outlinedButtonTheme.style?.minimumSize?.resolve(
            <WidgetState>{},
          ),
          const Size(48, 48),
        );
        expect(
          theme.textButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
          const Size(48, 48),
        );
        expect(
          theme.iconButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
          const Size.square(48),
        );
      }
    });
  });
}
