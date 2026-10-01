import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/geometry/text_note_geometry.dart';

void main() {
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
  });
}
