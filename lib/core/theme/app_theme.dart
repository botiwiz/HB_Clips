import 'package:flutter/material.dart';

/// HB_Clips theme: Miro-style dark grayscale canvas with a single pure-red
/// accent reserved for selection/highlight/critical states. Every other
/// surface, border, and text color is a shade of gray - deliberately, so
/// red always reads as "this is the one thing that matters right now."
class AppTheme {
  AppTheme._();

  static const Color canvasBackground = Color(0xFF18181A);
  static const Color surfaceCard = Color(0xFF26262A);
  static const Color surfaceElevated = Color(0xFF313136);
  static const Color border = Color(0xFF3A3A40);
  static const Color gridDot = border;

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9B9BA1);
  static const Color textDisabled = Color(0xFF5C5C62);

  /// The one accent color in the whole app. Used unmixed (never darkened)
  /// for borders/handles/icons; use `.withValues(alpha: ...)` rather than a
  /// different hex when a larger fill area needs a lighter touch.
  static const Color red = Color(0xFFFF0000);

  /// Aliases so call sites read by intent rather than repeating `red`.
  static const Color accent = red;
  static const Color danger = red;

  /// Text notes stay a light card (still grayscale - no hue) rather than
  /// going dark-on-dark, so they're still visually distinct from image
  /// clips against the dark canvas at a glance.
  static const Color textNoteSurface = Color(0xFFEDEDED);
  static const Color textNoteText = Color(0xFF1A1A1A);

  static ThemeData get dark {
    final scheme = ColorScheme.dark(
      primary: textPrimary,
      onPrimary: canvasBackground,
      secondary: textSecondary,
      onSecondary: canvasBackground,
      error: red,
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

    return base.copyWith(
      scaffoldBackgroundColor: canvasBackground,
      iconTheme: const IconThemeData(color: textPrimary),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: surfaceCard,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: surfaceElevated,
        elevation: 4,
        shadowColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: red,
        inactiveTrackColor: border,
        thumbColor: red,
        overlayColor: red.withValues(alpha: 0.15),
      ),
    );
  }
}
