import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/theme/app_theme.dart';
import 'package:hb_clips/core/theme/theme_settings.dart';

void main() {
  group('readableOn', () {
    test('white on a bright background', () {
      expect(AppTheme.readableOn(const Color(0xFFFFFFFF)), Colors.black);
    });

    test('white on a dark background', () {
      expect(AppTheme.readableOn(const Color(0xFF000000)), Colors.white);
    });

    test('white on the neon-green preset accent (bright)', () {
      expect(AppTheme.readableOn(const Color(0xFFA8FF3E)), Colors.black);
    });

    test('white on the hot-pink preset accent (dark-ish)', () {
      expect(AppTheme.readableOn(const Color(0xFFFF2E8F)), Colors.white);
    });
  });

  group('themeFor', () {
    test(
      "updates every mutable AppTheme.* field to match the given settings",
      () {
        const settings = ThemeSettings(
          accent: Color(0xFFA8FF3E),
          danger: Color(0xFF123456),
          canvasBackground: Color(0xFF111111),
          surfaceCard: Color(0xFF222222),
          surfaceElevated: Color(0xFF333333),
          border: Color(0xFF444444),
          textPrimary: Color(0xFF555555),
          textSecondary: Color(0xFF666666),
        );

        AppTheme.themeFor(settings);

        expect(AppTheme.accent, settings.accent);
        expect(AppTheme.danger, settings.danger);
        expect(AppTheme.canvasBackground, settings.canvasBackground);
        expect(AppTheme.surfaceCard, settings.surfaceCard);
        expect(AppTheme.surfaceElevated, settings.surfaceElevated);
        expect(AppTheme.border, settings.border);
        expect(AppTheme.textPrimary, settings.textPrimary);
        expect(AppTheme.textSecondary, settings.textSecondary);
        expect(AppTheme.gridDot, settings.border);
      },
    );

    test('resetting to builtInDefault restores the original look', () {
      AppTheme.themeFor(
        const ThemeSettings(
          accent: Color(0xFFA8FF3E),
          danger: Color(0xFF123456),
          canvasBackground: Color(0xFF111111),
          surfaceCard: Color(0xFF222222),
          surfaceElevated: Color(0xFF333333),
          border: Color(0xFF444444),
          textPrimary: Color(0xFF555555),
          textSecondary: Color(0xFF666666),
        ),
      );

      AppTheme.themeFor(ThemeSettings.builtInDefault);

      expect(AppTheme.accent, ThemeSettings.builtInDefault.accent);
      expect(AppTheme.danger, ThemeSettings.builtInDefault.danger);
      expect(
        AppTheme.canvasBackground,
        ThemeSettings.builtInDefault.canvasBackground,
      );
      expect(AppTheme.border, ThemeSettings.builtInDefault.border);
    });

    test('the returned ThemeData fills its primary button with accent', () {
      const settings = ThemeSettings(
        accent: Color(0xFFA8FF3E),
        danger: Color(0xFFFF0000),
        canvasBackground: Color(0xFF18181A),
        surfaceCard: Color(0xFF26262A),
        surfaceElevated: Color(0xFF313136),
        border: Color(0xFF3A3A40),
        textPrimary: Color(0xFFF5F5F5),
        textSecondary: Color(0xFF9B9BA1),
      );

      final theme = AppTheme.themeFor(settings);

      expect(
        theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
        settings.accent,
      );
    });
  });
}
