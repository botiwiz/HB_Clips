import 'package:flutter/material.dart';

import '../../data/local/database.dart' show ThemeRow;
import '../../features/annotation/stroke_painter.dart'
    show hexToColor, colorToHex;

/// The complete, switchable visual identity this app applies - every chrome
/// color `AppTheme` resolves, plus the chosen font family/size - bundled as
/// one value so a saved "theme" captures a complete look, not independent
/// settings that could drift out of sync with each other.
class ThemeSettings {
  final Color accent;
  final Color danger;
  final Color canvasBackground;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// A `google_fonts` family name (e.g. `'Chakra Petch'`), or null for the
  /// platform's default font - see `theme_fonts.dart`'s `kThemeFontChoices`.
  final String? fontFamily;

  /// Applied as a `MediaQuery` text-scale factor - 1.0 is today's sizes,
  /// unchanged. See `lib/app.dart`.
  final double fontSizeScale;

  const ThemeSettings({
    required this.accent,
    required this.danger,
    required this.canvasBackground,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    this.fontFamily,
    this.fontSizeScale = 1.0,
  });

  /// The app's original look, byte-for-byte - every value this file's
  /// predecessor (`AppTheme`'s old `const` fields) used before this theming
  /// system existed. `AppSettings.activeThemeId == null` always resolves to
  /// exactly this, so "no theme chosen" never looks any different than the
  /// app did before this feature shipped.
  static const builtInDefault = ThemeSettings(
    accent: Color(0xFFFF0000),
    danger: Color(0xFFFF0000),
    canvasBackground: Color(0xFF18181A),
    surfaceCard: Color(0xFF26262A),
    surfaceElevated: Color(0xFF313136),
    border: Color(0xFF3A3A40),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFF9B9BA1),
  );

  factory ThemeSettings.fromRow(ThemeRow row) => ThemeSettings(
    accent: hexToColor(row.accentHex),
    danger: hexToColor(row.dangerHex),
    canvasBackground: hexToColor(row.canvasBackgroundHex),
    surfaceCard: hexToColor(row.surfaceCardHex),
    surfaceElevated: hexToColor(row.surfaceElevatedHex),
    border: hexToColor(row.borderHex),
    textPrimary: hexToColor(row.textPrimaryHex),
    textSecondary: hexToColor(row.textSecondaryHex),
    fontFamily: row.fontFamily,
    fontSizeScale: row.fontSizeScale,
  );

  ThemeSettings copyWith({
    Color? accent,
    Color? danger,
    Color? canvasBackground,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Object? fontFamily = _unset,
    double? fontSizeScale,
  }) {
    return ThemeSettings(
      accent: accent ?? this.accent,
      danger: danger ?? this.danger,
      canvasBackground: canvasBackground ?? this.canvasBackground,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      fontFamily: identical(fontFamily, _unset)
          ? this.fontFamily
          : fontFamily as String?,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
    );
  }
}

/// Sentinel distinguishing "argument omitted" from "argument explicitly
/// passed as null" for [ThemeSettings.copyWith]'s nullable [String?
/// fontFamily] - a plain `fontFamily ?? this.fontFamily` would make it
/// impossible to ever copy a value back to "system default" (null).
const Object _unset = Object();

/// Two built-in, non-deletable presets - stable well-known ids so
/// `AppSettings.activeThemeId` can reference either directly without a DB
/// row, same "hardcoded named preset" pattern `frame_presets.dart`'s
/// `kFramePresets` already uses. Answers the pink-vs-green reference-image
/// question by shipping both as one-click choices rather than picking one.
const Map<String, ThemeSettings> kBuiltInThemes = {
  'builtin-hot-pink': ThemeSettings(
    accent: Color(0xFFFF2E8F),
    danger: Color(0xFFFF0000),
    canvasBackground: Color(0xFF18181A),
    surfaceCard: Color(0xFF26262A),
    surfaceElevated: Color(0xFF313136),
    border: Color(0xFF3A3A40),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFF9B9BA1),
    fontFamily: 'Chakra Petch',
  ),
  'builtin-neon-green': ThemeSettings(
    accent: Color(0xFFA8FF3E),
    danger: Color(0xFFFF0000),
    canvasBackground: Color(0xFF18181A),
    surfaceCard: Color(0xFF26262A),
    surfaceElevated: Color(0xFF313136),
    border: Color(0xFF3A3A40),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFF9B9BA1),
    fontFamily: 'Chakra Petch',
  ),
};

/// Display name shown in the Settings dialog's saved-themes list for a
/// built-in preset id - [kBuiltInThemes]' own keys are stable identifiers,
/// not meant for display.
const Map<String, String> kBuiltInThemeNames = {
  'builtin-hot-pink': 'Hot Pink HUD',
  'builtin-neon-green': 'Neon Green HUD',
};

/// `ThemeSettings`'s 8 colors as `#RRGGBB` hex, keyed for `ThemesRepository
/// .createTheme`/`updateTheme` - the inverse of `ThemeSettings.fromRow`.
extension ThemeSettingsHex on ThemeSettings {
  String get accentHex => colorToHex(accent);
  String get dangerHex => colorToHex(danger);
  String get canvasBackgroundHex => colorToHex(canvasBackground);
  String get surfaceCardHex => colorToHex(surfaceCard);
  String get surfaceElevatedHex => colorToHex(surfaceElevated);
  String get borderHex => colorToHex(border);
  String get textPrimaryHex => colorToHex(textPrimary);
  String get textSecondaryHex => colorToHex(textSecondary);
}
