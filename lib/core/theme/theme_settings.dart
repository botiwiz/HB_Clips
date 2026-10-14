import 'package:flutter/material.dart';

import '../../data/local/database.dart' show ThemeRow;
import '../../features/annotation/stroke_painter.dart'
    show hexToColor, colorToHex;
import '../constants.dart' show kDefaultGridCrossInterval;

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

  /// Every `gridCrossInterval`-th dot (in both grid axes) of the board's
  /// dot-grid background renders as a small "+" cross instead of a plain
  /// dot - see `dot_grid_background.dart`'s `DotGridPainter`.
  final int gridCrossInterval;

  /// Multiplier on `kGridCrossBaseHalfLength` for a grid cross's on-screen
  /// size - 1.0 is the original fixed size, unchanged.
  final double gridCrossScale;

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
    this.gridCrossInterval = kDefaultGridCrossInterval,
    this.gridCrossScale = 1.0,
  });

  /// The app's original look, byte-for-byte - every value this file's
  /// predecessor (`AppTheme`'s old `const` fields) used before this theming
  /// system existed. Used only as the code-level fallback when
  /// `AppSettings.activeThemeId` is null or references a deleted theme
  /// (e.g. every saved preset has been removed) - not a user-facing
  /// "DEFAULT" option any more (see `kSeedThemePresets` and
  /// `ThemesRepository.ensureSeeded`).
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
    gridCrossInterval: row.gridCrossInterval,
    gridCrossScale: row.gridCrossScale,
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
    int? gridCrossInterval,
    double? gridCrossScale,
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
      gridCrossInterval: gridCrossInterval ?? this.gridCrossInterval,
      gridCrossScale: gridCrossScale ?? this.gridCrossScale,
    );
  }
}

/// Sentinel distinguishing "argument omitted" from "argument explicitly
/// passed as null" for [ThemeSettings.copyWith]'s nullable [String?
/// fontFamily] - a plain `fontFamily ?? this.fontFamily` would make it
/// impossible to ever copy a value back to "system default" (null).
const Object _unset = Object();

/// Starting look + name for each of the 3 presets `ThemesRepository
/// .ensureSeeded` writes into the `themes` table the first time the app
/// runs (or upgrades from a version that had no saved themes yet) - after
/// that they're ordinary saved themes like any other: fully renamable,
/// recolorable, and deletable, with no fixed "DEFAULT"/built-in distinction
/// baked into the app any more. Keeps the 3 looks this app has always
/// shipped with as a starting point rather than leaving a user who already
/// picked one of them (under the old hardcoded-built-in scheme) with
/// nothing on upgrade.
const List<(String name, ThemeSettings settings)> kSeedThemePresets = [
  ('Default', ThemeSettings.builtInDefault),
  (
    'Hot Pink HUD',
    ThemeSettings(
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
  ),
  (
    'Neon Green HUD',
    ThemeSettings(
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
  ),
];

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
