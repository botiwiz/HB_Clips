import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/geometry/text_style_ranges.dart';

void main() {
  group('toggle', () {
    test('on empty ranges, adds one', () {
      final result = TextStyleRanges.toggle(const [], 2, 5);
      expect(result, [(start: 2, end: 5)]);
    });

    test('toggling exactly an existing range removes it', () {
      final result = TextStyleRanges.toggle([(start: 2, end: 5)], 2, 5);
      expect(result, isEmpty);
    });

    test('toggling a sub-range of a larger range splits into two pieces', () {
      final result = TextStyleRanges.toggle([(start: 0, end: 10)], 3, 6);
      expect(result, [(start: 0, end: 3), (start: 6, end: 10)]);
    });

    test('toggling a partially-overlapping range merges to one larger range', () {
      final result = TextStyleRanges.toggle([(start: 0, end: 5)], 3, 8);
      expect(result, [(start: 0, end: 8)]);
    });

    test('toggling an adjacent range merges (touching ranges coalesce)', () {
      final result = TextStyleRanges.toggle([(start: 0, end: 5)], 5, 8);
      expect(result, [(start: 0, end: 8)]);
    });

    test('toggling a disjoint range adds a separate entry', () {
      final result = TextStyleRanges.toggle([(start: 0, end: 5)], 10, 15);
      expect(result, [(start: 0, end: 5), (start: 10, end: 15)]);
    });

    test('a zero-length toggle (collapsed selection) is a no-op', () {
      final result = TextStyleRanges.toggle([(start: 0, end: 5)], 3, 3);
      expect(result, [(start: 0, end: 5)]);
    });
  });

  group('isFullyCovered', () {
    test('true when a single range fully covers the span', () {
      expect(TextStyleRanges.isFullyCovered([(start: 0, end: 10)], 3, 6), isTrue);
    });

    test('true when multiple adjacent ranges together cover the span', () {
      final ranges = [(start: 0, end: 3), (start: 3, end: 6)];
      expect(TextStyleRanges.isFullyCovered(ranges, 1, 5), isTrue);
    });

    test('false when there is a gap', () {
      final ranges = [(start: 0, end: 2), (start: 4, end: 6)];
      expect(TextStyleRanges.isFullyCovered(ranges, 0, 6), isFalse);
    });

    test('false when only partially covered', () {
      expect(TextStyleRanges.isFullyCovered([(start: 0, end: 3)], 0, 6), isFalse);
    });
  });

  group('buildSpans', () {
    test('no formatting produces a single span with the base style', () {
      final spans = TextStyleRanges.buildSpans(
        'hello',
        TextFormatting.empty,
        const TextStyle(fontSize: 14),
      );
      expect(spans, hasLength(1));
      expect(spans.single.text, 'hello');
      expect(spans.single.style?.fontWeight, isNull);
    });

    test('a bold range splits into 3 runs with the middle one bold', () {
      const formatting = TextFormatting(bold: [(start: 2, end: 4)]);
      final spans = TextStyleRanges.buildSpans(
        'abcdef',
        formatting,
        const TextStyle(fontSize: 14),
      );

      expect(spans.map((s) => s.text), ['ab', 'cd', 'ef']);
      expect(spans[0].style?.fontWeight, isNull);
      expect(spans[1].style?.fontWeight, FontWeight.bold);
      expect(spans[2].style?.fontWeight, isNull);
    });

    test('overlapping bold and italic ranges combine on the shared run', () {
      const formatting = TextFormatting(
        bold: [(start: 0, end: 4)],
        italic: [(start: 2, end: 6)],
      );
      final spans = TextStyleRanges.buildSpans(
        'abcdef',
        formatting,
        const TextStyle(fontSize: 14),
      );

      expect(spans.map((s) => s.text), ['ab', 'cd', 'ef']);
      expect(spans[0].style?.fontWeight, FontWeight.bold);
      expect(spans[0].style?.fontStyle, isNull);
      expect(spans[1].style?.fontWeight, FontWeight.bold);
      expect(spans[1].style?.fontStyle, FontStyle.italic);
      expect(spans[2].style?.fontWeight, isNull);
      expect(spans[2].style?.fontStyle, FontStyle.italic);
    });

    test('strikethrough applies TextDecoration.lineThrough', () {
      const formatting = TextFormatting(strikethrough: [(start: 0, end: 3)]);
      final spans = TextStyleRanges.buildSpans(
        'abc',
        formatting,
        const TextStyle(fontSize: 14),
      );

      expect(spans, hasLength(1));
      expect(spans.single.style?.decoration, TextDecoration.lineThrough);
    });

    test('underline applies TextDecoration.underline', () {
      const formatting = TextFormatting(underline: [(start: 0, end: 3)]);
      final spans = TextStyleRanges.buildSpans(
        'abc',
        formatting,
        const TextStyle(fontSize: 14),
      );

      expect(spans, hasLength(1));
      expect(spans.single.style?.decoration, TextDecoration.underline);
    });

    test('underline and strikethrough on the same run combine', () {
      const formatting = TextFormatting(
        underline: [(start: 0, end: 3)],
        strikethrough: [(start: 0, end: 3)],
      );
      final spans = TextStyleRanges.buildSpans(
        'abc',
        formatting,
        const TextStyle(fontSize: 14),
      );

      expect(spans, hasLength(1));
      expect(
        spans.single.style?.decoration,
        TextDecoration.combine([
          TextDecoration.underline,
          TextDecoration.lineThrough,
        ]),
      );
    });

    test('empty text returns a single empty span', () {
      final spans = TextStyleRanges.buildSpans(
        '',
        TextFormatting.empty,
        const TextStyle(fontSize: 14),
      );
      expect(spans, hasLength(1));
      expect(spans.single.text, '');
    });
  });
}
