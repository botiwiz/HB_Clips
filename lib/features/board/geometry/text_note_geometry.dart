import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../data/models/clip.dart';
import 'text_style_ranges.dart';

/// Pure board-space text-measurement helper backing a text note's
/// auto-grow-height behavior - the inverse of how `ClipWidget`/
/// `TextClipEditOverlay` already render a note (same
/// `TextStyleRanges.buildSpans` call, same `TextNoteGeometry.baseStyle`,
/// same [kTextNoteHorizontalPadding]/[kTextNoteVerticalPadding]), so
/// rendering and this measurement can never disagree. Everything here is
/// board-space (never multiplied by `view.scale`) - same "world unit"
/// convention as every other board-space constant in this app.
class TextNoteGeometry {
  TextNoteGeometry._();

  /// The exact [TextStyle] every text-note render/measurement path must
  /// use. Pins every field Flutter's Material theme-merge machinery
  /// (`TextStyle.merge`, used internally by both `TextField` and
  /// `Text`/`Text.rich`) could otherwise silently fill in from an
  /// ambient `Theme`/`DefaultTextStyle` - `letterSpacing`, `fontWeight`,
  /// `fontStyle`, `decoration`, `height` - to an explicit, non-null
  /// value (`TextStyle.merge` only ever fills fields the caller's style
  /// left null). Without this, `TextField` picks up Material 3's
  /// `bodyLarge.letterSpacing` (0.5) and `Text`/`Text.rich` picks up
  /// `bodyMedium.letterSpacing` (0.25) - two different values, neither
  /// matching the 0 this measurement assumes - which makes real text
  /// wrap to more lines than predicted and clips the last one.
  /// `fontFamily` is deliberately left unset: this app sets no ambient
  /// `ThemeData.fontFamily`/custom `textTheme` font anywhere, so every
  /// path already resolves to the same engine default - and unlike the
  /// other fields, there's no non-null value that means "pin to
  /// framework default", so there is nothing to gain by writing
  /// `fontFamily: null` explicitly.
  static TextStyle baseStyle({required double fontSize, Color? color}) =>
      TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.normal,
        letterSpacing: 0,
        decoration: TextDecoration.none,
        height: kTextNoteLineHeight,
      );

  /// Board-space height needed to render [text]/[formatting] at
  /// board-space [fontSize], wrapped to board-space [width].
  static double requiredHeight({
    required String text,
    required TextFormatting formatting,
    required double fontSize,
    required double width,
  }) {
    final innerWidth = width - 2 * kTextNoteHorizontalPadding;
    // Mirrors ClipWidget._buildText()/rasterizeTextClip's own correction
    // (see kTextCaretReservedWidth's doc comment) - without it, this
    // measurement wraps a line later than every real render path does,
    // silently under-predicting height by a line in some cases. This
    // was the actual root cause of a text note occasionally needing an
    // extra edit (a space/Enter) before its full content became
    // visible: the callers of this function (board_canvas.dart's
    // resize-drag auto-fit, and this file's own undo/redo height
    // predictions) only ever predict - they have no live TextField to
    // measure - so an under-prediction here persisted directly as
    // `clip.height`, clipping the last line until the next real edit
    // re-measured and self-corrected it.
    final contentWidth = innerWidth > kTextCaretReservedWidth
        ? innerWidth - kTextCaretReservedWidth
        : innerWidth;
    final painter = TextPainter(
      text: TextSpan(
        children: TextStyleRanges.buildSpans(
          text,
          formatting,
          baseStyle(fontSize: fontSize),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: contentWidth < 1 ? 1 : contentWidth);
    return painter.height + 2 * kTextNoteVerticalPadding;
  }
}
