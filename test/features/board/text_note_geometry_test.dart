import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/geometry/text_note_geometry.dart';

void main() {
  group('baseStyle', () {
    test(
      'pins every field TextStyle.merge could otherwise inject from an ambient theme',
      () {
        final style = TextNoteGeometry.baseStyle(fontSize: 14);
        expect(style.fontSize, 14);
        expect(style.letterSpacing, 0);
        expect(style.height, kTextNoteLineHeight);
        expect(style.fontWeight, FontWeight.w400);
        expect(style.fontStyle, FontStyle.normal);
        expect(style.decoration, TextDecoration.none);
      },
    );
  });

  group('requiredHeight', () {
    test('empty text gives roughly one line of height', () {
      final height = TextNoteGeometry.requiredHeight(
        text: '',
        formatting: TextFormatting.empty,
        fontSize: 14,
        width: 220,
      );
      // One line at fontSize 14, height multiplier 1.3, plus vertical
      // padding on both edges - a generous sanity range rather than
      // asserting an exact pixel value tied to font-metrics internals.
      expect(height, greaterThan(14));
      expect(height, lessThan(40));
    });

    test('text long enough to wrap to 2 lines is taller than 1 line', () {
      final oneLine = TextNoteGeometry.requiredHeight(
        text: 'short',
        formatting: TextFormatting.empty,
        fontSize: 14,
        width: 400,
      );
      final twoLines = TextNoteGeometry.requiredHeight(
        text: 'a very long line of text that will not fit on one row',
        formatting: TextFormatting.empty,
        fontSize: 14,
        width: 400,
      );
      expect(twoLines, greaterThan(oneLine));
    });

    test('the same text at a narrower width wraps more and is taller', () {
      const text = 'a very long line of text that will not fit on one row';
      final wide = TextNoteGeometry.requiredHeight(
        text: text,
        formatting: TextFormatting.empty,
        fontSize: 14,
        width: 600,
      );
      final narrow = TextNoteGeometry.requiredHeight(
        text: text,
        formatting: TextFormatting.empty,
        fontSize: 14,
        width: 120,
      );
      expect(narrow, greaterThan(wide));
    });

    test('subtracts kTextCaretReservedWidth before wrapping, matching every '
        'real render path (ClipWidget/rasterizeTextClip) - without this, '
        'text that just barely fits on one line at the UNcorrected width '
        'wraps onto a second line once the real, narrower render width is '
        'used, and this measurement would have silently under-predicted '
        'the height needed by a whole line', () {
      const text = 'AAAAAAAAAA BBBBBBBBBB';
      const fontSize = 14.0;
      final style = TextNoteGeometry.baseStyle(fontSize: fontSize);
      final naturalWidth = (TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout()).width;

      // Wide enough to fit both words on one line at the natural
      // (uncorrected) width, but once kTextCaretReservedWidth (3.0)
      // is subtracted, narrower than the text itself - forcing a wrap.
      final boundaryWidth = naturalWidth + 2 * kTextNotePadding + 1.0;
      // Comfortably wider still, so both correction and non-correction
      // agree this fits on one line - the baseline to compare against.
      final comfortableWidth = boundaryWidth + kTextCaretReservedWidth * 4;

      final atBoundary = TextNoteGeometry.requiredHeight(
        text: text,
        formatting: TextFormatting.empty,
        fontSize: fontSize,
        width: boundaryWidth,
      );
      final comfortable = TextNoteGeometry.requiredHeight(
        text: text,
        formatting: TextFormatting.empty,
        fontSize: fontSize,
        width: comfortableWidth,
      );

      expect(atBoundary, greaterThan(comfortable));
    });

    test('a bold range does not crash and is at least as tall', () {
      const text = 'hello world';
      final plain = TextNoteGeometry.requiredHeight(
        text: text,
        formatting: TextFormatting.empty,
        fontSize: 14,
        width: 220,
      );
      final bold = TextNoteGeometry.requiredHeight(
        text: text,
        formatting: const TextFormatting(bold: [(start: 0, end: 5)]),
        fontSize: 14,
        width: 220,
      );
      expect(bold, greaterThanOrEqualTo(plain));
    });

    test(
      'single-line text is sized from where the last glyph landed, not from how long '
      'that one line is - two different single-line strings at the same fontSize produce '
      'the exact same height, since the caret for both sits on the same (only) line',
      () {
        const fontSize = 14.0;
        final short = TextNoteGeometry.requiredHeight(
          text: 'hi',
          formatting: TextFormatting.empty,
          fontSize: fontSize,
          width: 400,
        );
        final longerButStillOneLine = TextNoteGeometry.requiredHeight(
          text: 'a somewhat longer line that still fits on one row',
          formatting: TextFormatting.empty,
          fontSize: fontSize,
          width: 1000,
        );
        expect(longerButStillOneLine, equals(short));
        // Sanity range rather than an exact pixel value tied to font-metric
        // internals (same convention as the other requiredHeight tests
        // above) - one line's content plus padding should land well under
        // two lines' worth of room.
        expect(short, greaterThan(fontSize));
        expect(short, lessThan(fontSize * 2));
      },
    );
  });
}
