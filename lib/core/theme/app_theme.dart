import 'package:flutter/material.dart';

/// HB_Clips theme: a dark, neutral canvas so image clips (which carry their
/// own color) stay the visual focus, similar to PureRef's dark board.
class AppTheme {
  AppTheme._();

  static const Color boardBackground = Color(0xFF1E1F22);
  static const Color surface = Color(0xFF2B2D31);
  static const Color accent = Color(0xFF5B8DEF);
  static const Color danger = Color(0xFFE5484D);
  static const Color warning = Color(0xFFE5A64D);

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: boardBackground,
    );
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: surface,
        elevation: 0,
      ),
    );
  }
}
