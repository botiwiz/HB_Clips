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

    test(
      'toggling a partially-overlapping range merges to one larger range',
      () {
        final result = TextStyleRanges.toggle([(start: 0, end: 5)], 3, 8);
        expect(result, [(start: 0, end: 8)]);
      },
    );

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
      expect(
        TextStyleRanges.isFullyCovered([(start: 0, end: 10)], 3, 6),
        isTrue,
      );
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
      expect(
        TextStyleRanges.isFullyCovered([(start: 0, end: 3)], 0, 6),
        isFalse,
      );
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

  group('diffText', () {
    test('no change', () {
      final diff = TextStyleRanges.diffText('hello', 'hello');
      expect(diff, (start: 5, deletedLength: 0, insertedLength: 0));
    });

    test('pure append', () {
      final diff = TextStyleRanges.diffText('hello', 'hello world');
      expect(diff, (start: 5, deletedLength: 0, insertedLength: 6));
    });

    test('pure prepend', () {
      final diff = TextStyleRanges.diffText('world', 'hello world');
      expect(diff, (start: 0, deletedLength: 0, insertedLength: 6));
    });

    test('insertion in the middle', () {
      final diff = TextStyleRanges.diffText('ac', 'abc');
      expect(diff, (start: 1, deletedLength: 0, insertedLength: 1));
    });

    test('deletion in the middle', () {
      final diff = TextStyleRanges.diffText('abc', 'ac');
      expect(diff, (start: 1, deletedLength: 1, insertedLength: 0));
    });

    test('deleting a prefix before some trailing text', () {
      final diff = TextStyleRanges.diffText('Hello world', 'world');
      expect(diff, (start: 0, deletedLength: 6, insertedLength: 0));
    });

    test('select-and-replace (overlapping delete+insert)', () {
      final diff = TextStyleRanges.diffText('hello world', 'hello there');
      expect(diff, (start: 6, deletedLength: 5, insertedLength: 5));
    });

    test('full replace with no common prefix/suffix', () {
      final diff = TextStyleRanges.diffText('abc', 'xyz');
      expect(diff, (start: 0, deletedLength: 3, insertedLength: 3));
    });
  });

  group('shiftRanges', () {
    test(
      'deleting text before a range shifts it back so it still covers the same characters',
      () {
        // Reproduces the reported bug: "Hello world" with "world" bold,
        // then "Hello " is deleted - the bold range must follow "world" to
        // its new position, not stay stuck at its old (now wrong) indices.
        final diff = TextStyleRanges.diffText('Hello world', 'world');
        final result = TextStyleRanges.shiftRanges(
          [(start: 6, end: 11)],
          diff.start,
          diff.deletedLength,
          diff.insertedLength,
        );
        expect(result, [(start: 0, end: 5)]);
      },
    );

    test('inserting text before a range shifts it forward', () {
      final diff = TextStyleRanges.diffText('world', 'Hello world');
      final result = TextStyleRanges.shiftRanges(
        [(start: 0, end: 5)],
        diff.start,
        diff.deletedLength,
        diff.insertedLength,
      );
      expect(result, [(start: 6, end: 11)]);
    });

    test(
      'inserting exactly at the start of a range does not extend it backward',
      () {
        final result = TextStyleRanges.shiftRanges(
          [(start: 0, end: 5)],
          0,
          0,
          1,
        );
        expect(result, [(start: 1, end: 6)]);
      },
    );

    test(
      'inserting exactly at the end of a range extends it (continuing to type stays bold)',
      () {
        final result = TextStyleRanges.shiftRanges(
          [(start: 0, end: 4)],
          4,
          0,
          1,
        );
        expect(result, [(start: 0, end: 5)]);
      },
    );

    test('deleting a range entirely removes it', () {
      final result = TextStyleRanges.shiftRanges([(start: 2, end: 5)], 2, 3, 0);
      expect(result, isEmpty);
    });

    test('deleting the tail of a range truncates it', () {
      final result = TextStyleRanges.shiftRanges(
        [(start: 0, end: 10)],
        6,
        4,
        0,
      );
      expect(result, [(start: 0, end: 6)]);
    });

    test('deleting the head of a range truncates it and shifts it back', () {
      final result = TextStyleRanges.shiftRanges(
        [(start: 4, end: 10)],
        0,
        4,
        0,
      );
      expect(result, [(start: 0, end: 6)]);
    });

    test('an edit entirely after a range leaves it untouched', () {
      final result = TextStyleRanges.shiftRanges(
        [(start: 0, end: 5)],
        10,
        2,
        0,
      );
      expect(result, [(start: 0, end: 5)]);
    });
  });

  group('shiftFormatting', () {
    test('shifts all 4 range lists together', () {
      final formatting = TextFormatting(
        bold: const [(start: 6, end: 11)],
        italic: const [(start: 0, end: 5)],
      );
      final diff = TextStyleRanges.diffText('Hello world', 'world');
      final result = TextStyleRanges.shiftFormatting(
        formatting,
        diff.start,
        diff.deletedLength,
        diff.insertedLength,
      );
      expect(result.bold, [(start: 0, end: 5)]);
      expect(result.italic, isEmpty);
    });
  });
}
