import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Display name -> `google_fonts` family name offered in the Settings
/// dialog's font-family row. `null` means "system default" (no
/// `google_fonts` override at all). A plain map rather than an enum so
/// adding another choice later is a one-line entry here, not a new
/// `GoogleFonts.xxxTextTheme` call site.
const Map<String, String?> kThemeFontChoices = {
  'System default': null,
  'Chakra Petch': 'Chakra Petch',
  'Rajdhani': 'Rajdhani',
  'Orbitron': 'Orbitron',
  'Share Tech Mono': 'Share Tech Mono',
};

/// Resolves [fontFamily] (a `google_fonts` family name, or null for system
/// default) against [base] - the `TextTheme` every inline `TextStyle(
/// fontSize/fontWeight)` call site across the app merges onto, per
/// `TextStyle.merge`'s "only overrides fields the inline style actually
/// sets" behavior, so this is the one place a font choice needs to be
/// applied for it to cascade everywhere. Returns [base] unchanged for
/// system default - this app's exact pre-theming-system look.
TextTheme resolveFontTextTheme(String? fontFamily, TextTheme base) {
  if (fontFamily == null) return base;
  return GoogleFonts.getTextTheme(fontFamily, base);
}
