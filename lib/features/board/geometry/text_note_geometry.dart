import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../data/models/clip.dart';
import 'text_style_ranges.dart';

/// Pure board-space text-measurement helper backing a text note's
/// auto-grow-height behavior - the inverse of how `ClipWidget`/
/// `TextClipEditOverlay` already render a note (same
/// `TextStyleRanges.buildSpans` call, same `height: 1.3` line multiplier,
/// same [kTextNoteHorizontalPadding]/[kTextNoteVerticalPadding]), so
/// rendering and this measurement can never disagree. Everything here is
/// board-space (never multiplied by `view.scale`) - same "world unit"
/// convention as every other board-space constant in this app.
class TextNoteGeometry {
  TextNoteGeometry._();

  /// Board-space height needed to render [text]/[formatting] at
  /// board-space [fontSize], wrapped to board-space [width].
  static double requiredHeight({
    required String text,
    required TextFormatting formatting,
    required double fontSize,
    required double width,
  }) {
    final innerWidth = width - 2 * kTextNoteHorizontalPadding;
    final painter = TextPainter(
      text: TextSpan(
        children: TextStyleRanges.buildSpans(
          text,
          formatting,
          TextStyle(fontSize: fontSize, height: 1.3),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: innerWidth < 1 ? 1 : innerWidth);
    return painter.height + 2 * kTextNoteVerticalPadding;
  }
}
