import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../data/models/clip.dart';
import 'text_style_ranges.dart';

/// Pure board-space text-measurement helper backing a text note's
/// auto-grow-height behavior - the inverse of how `ClipWidget`/
/// `TextClipEditOverlay` already render a note (same
/// `TextStyleRanges.buildSpans` call, same `TextNoteGeometry.baseStyle`,
/// same [kTextNotePadding]), so
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
  /// board-space [fontSize], wrapped to board-space [width]. Used only by
  /// callers with no live `TextField` to measure (a width-resize drag or a
  /// font-size change while the note isn't being actively edited - see
  /// `board_canvas.dart`/`TextClipEditOverlay._adjustFontSize`); while a
  /// note is actively edited, `TextClipEditOverlay._scheduleHeightSync`
  /// measures Flutter's real rendered height directly instead of calling
  /// this at all.
  static double requiredHeight({
    required String text,
    required TextFormatting formatting,
    required double fontSize,
    required double width,
  }) {
    final innerWidth = width - 2 * kTextNotePadding;
    // Mirrors ClipWidget._buildText()/rasterizeTextClip's own correction
    // (see kTextCaretReservedWidth's doc comment) - without it, this
    // measurement wraps a line later than every real render path does.
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
    // Where a cursor would sit right after the very last character (the
    // same caret-placement math RenderEditable itself uses) - the top of
    // whichever line the last glyph landed on, already accounting for
    // every earlier line's real height (kTextNoteLineHeight included).
    // One more fontSize's worth of room covers that final line itself,
    // then padding on both edges - a tight fit defined by where the
    // content actually ends, instead of trusting TextPainter's own total
    // laid-out height (which reserves a full line-height's worth of
    // space below the last line even when the glyphs themselves don't
    // need it). Any small residual gap between this prediction and
    // Flutter's real layout is now harmless either way - ClipWidget no
    // longer clips a text note's content to its box.
    final lastLineTop = painter
        .getOffsetForCaret(TextPosition(offset: text.length), Rect.zero)
        .dy;
    return lastLineTop + fontSize + 2 * kTextNotePadding;
  }
}
