import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/geometry/highlight_geometry.dart';

void main() {
  group('rectsFor', () {
    test('no highlight ranges produces no rects', () {
      final rects = HighlightGeometry.rectsFor(
        text: 'hello world',
        formatting: TextFormatting.empty,
        baseStyle: const TextStyle(fontSize: 14),
        width: 400,
        cornerRadius: 3.5,
      );
      expect(rects, isEmpty);
    });

    test('empty text produces no rects even with a highlight range', () {
      final rects = HighlightGeometry.rectsFor(
        text: '',
        formatting: const TextFormatting(highlight: [(start: 0, end: 3)]),
        baseStyle: const TextStyle(fontSize: 14),
        width: 400,
        cornerRadius: 3.5,
      );
      expect(rects, isEmpty);
    });

    test('a highlighted range on one line produces one rounded rect', () {
      final rects = HighlightGeometry.rectsFor(
        text: 'hello world',
        formatting: const TextFormatting(highlight: [(start: 0, end: 5)]),
        baseStyle: const TextStyle(fontSize: 14),
        width: 400,
        cornerRadius: 3.5,
      );
      expect(rects, hasLength(1));
      expect(rects.single.blRadiusX, 3.5);
      // The highlighted rect starts at the left edge and is narrower than
      // the full line (only "hello" is highlighted, not "hello world").
      expect(rects.single.left, 0);
      expect(rects.single.width, lessThan(400));
      expect(rects.single.width, greaterThan(0));
    });

    test('two separate highlighted ranges produce two rects', () {
      final rects = HighlightGeometry.rectsFor(
        text: 'hello world',
        formatting: const TextFormatting(
          highlight: [(start: 0, end: 5), (start: 6, end: 11)],
        ),
        baseStyle: const TextStyle(fontSize: 14),
        width: 400,
        cornerRadius: 3.5,
      );
      expect(rects, hasLength(2));
    });

    test('a highlighted range spanning a wrapped line produces 2 rects', () {
      final rects = HighlightGeometry.rectsFor(
        text: 'a very long line of text that will not fit on one row',
        formatting: const TextFormatting(highlight: [(start: 0, end: 55)]),
        baseStyle: const TextStyle(fontSize: 14),
        width: 120,
        cornerRadius: 3.5,
      );
      expect(rects.length, greaterThanOrEqualTo(2));
    });
  });
}
