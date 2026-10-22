import 'package:flutter/material.dart';

import '../constants.dart' show kCornerRadius;
import 'theme_fonts.dart';
import 'theme_settings.dart';

/// HB_Clips theme: a dark canvas whose chrome colors and typography are
/// driven by a [ThemeSettings] value (see that class and `Themes`/
/// `AppSettings.activeThemeId`) rather than fixed constants - a user can
/// pick/edit/save their own theme via the Settings dialog. Every field
/// below is a mutable static (not `const`) precisely so it can be updated
/// at runtime; [themeFor] is the one place that happens, called from
/// `lib/app.dart` whenever the resolved theme changes. Every other call
/// site across the app keeps reading these fields exactly as before -
/// `AppTheme.accent`/`AppTheme.border`/etc. - unaware that their value can
/// now vary, since Dart doesn't distinguish a `static const` read from a
/// mutable `static` read at the call site.
class AppTheme {
  AppTheme._();

  static Color canvasBackground = ThemeSettings.builtInDefault.canvasBackground;
  static Color surfaceCard = ThemeSettings.builtInDefault.surfaceCard;
  static Color surfaceElevated = ThemeSettings.builtInDefault.surfaceElevated;
  static Color border = ThemeSettings.builtInDefault.border;
  static Color get gridDot => border;

  static Color textPrimary = ThemeSettings.builtInDefault.textPrimary;
  static Color textSecondary = ThemeSettings.builtInDefault.textSecondary;
  static const Color textDisabled = Color(0xFF5C5C62);

  /// The one color reserved for selection/highlight/active-state chrome -
  /// independently editable from [danger] (they happen to share a value in
  /// [ThemeSettings.builtInDefault], but that's no longer guaranteed).
  static Color accent = ThemeSettings.builtInDefault.accent;

  /// Reserved for destructive/delete actions specifically - kept visually
  /// distinct from [accent] so "this is the one thing that matters right
  /// now" and "this is destructive" never collide just because a user
  /// picked an accent color that happens to look alarming.
  static Color danger = ThemeSettings.builtInDefault.danger;

  /// Live, per-theme cross-mark grid settings - see `ThemeSettings
  /// .gridCrossInterval`/`gridCrossScale`. Read directly by the three
  /// cross-mark painters (`DotGridPainter`, `pdf_writer.dart`'s
  /// `_drawDotGrid`, `_ExportDotGridPainter`), same "bare mutable static,
  /// no constructor plumbing" convention the 8 color fields above use.
  static int gridCrossInterval = ThemeSettings.builtInDefault.gridCrossInterval;
  static double gridCrossScale = ThemeSettings.builtInDefault.gridCrossScale;

  /// Text notes have no background card by default - just white text
  /// floating directly on the canvas - so they read as annotations rather
  /// than image-like tiles. A custom `backgroundColorHex` still overrides
  /// this per-note via the style popover's swatches. Deliberately NOT
  /// themed - this is about canvas *content* legibility, not UI chrome, so
  /// it stays fixed regardless of the active theme.
  static const Color textNoteSurface = Color(0x00000000);
  static const Color textNoteText = Colors.white;

  /// Black or white, whichever reads better on [background] - used
  /// wherever a color the user picked (a theme's accent, a board's custom
  //// tint, a filled button's background) needs legible text/icons on top
  /// of it, regardless of how light or dark that pick turns out to be.
  static Color readableOn(Color background) =>
      background.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  /// Builds the app's [ThemeData] from [settings], first updating every
  /// mutable field above so every other `AppTheme.*` call site across the
  /// app (none of which know about [ThemeSettings] at all) immediately
  /// reflects it too. Call this, then rebuild, whenever the resolved theme
  /// changes - see `lib/app.dart`'s `resolvedThemeSettingsProvider` watch.
  static ThemeData themeFor(ThemeSettings settings) {
    canvasBackground = settings.canvasBackground;
    surfaceCard = settings.surfaceCard;
    surfaceElevated = settings.surfaceElevated;
    border = settings.border;
    textPrimary = settings.textPrimary;
    textSecondary = settings.textSecondary;
    accent = settings.accent;
    danger = settings.danger;
    gridCrossInterval = settings.gridCrossInterval;
    gridCrossScale = settings.gridCrossScale;

    final scheme = ColorScheme.dark(
      primary: textPrimary,
      onPrimary: canvasBackground,
      secondary: textSecondary,
      onSecondary: canvasBackground,
      error: danger,
      onError: Colors.white,
      surface: surfaceCard,
      onSurface: textPrimary,
      outline: border,
    );

    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: scheme,
    );

    final borderedShape = RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(kCornerRadius)),
      side: BorderSide(color: border, width: 1),
    );

    return base.copyWith(
      scaffoldBackgroundColor: canvasBackground,
      iconTheme: IconThemeData(color: textPrimary),
      textTheme: resolveFontTextTheme(
        settings.fontFamily,
        base.textTheme,
      ).apply(bodyColor: textPrimary, displayColor: textPrimary),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: surfaceCard,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 0,
        shape: borderedShape,
      ),
      // Material 3's AlertDialog/PopupMenuButton default to a built-in
      // 28px-radius shape with no override anywhere in this app - these
      // two are the one place that needs to change to make every
      // existing/future dialog and popup menu sharp (and, now, thinly
      // bordered), without touching each individual showDialog/
      // PopupMenuButton call site.
      dialogTheme: DialogThemeData(shape: borderedShape, elevation: 0),
      popupMenuTheme: PopupMenuThemeData(shape: borderedShape, elevation: 0),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: accent,
        inactiveTrackColor: border,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: readableOn(accent),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(kCornerRadius)),
          ),
        ),
      ),
    );
  }
}
