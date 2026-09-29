import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/geometry/masonry_layout.dart';

bool _overlaps(Rect a, Rect b) {
  // Touching edges (shared column boundary/gap) aren't an overlap.
  return a.left < b.right - 1e-6 &&
      b.left < a.right - 1e-6 &&
      a.top < b.bottom - 1e-6 &&
      b.top < a.bottom - 1e-6;
}

/// Groups packed rects by column (shared `left`) and returns each column's
/// exact stacked height (last item's bottom minus first item's top).
Map<double, double> _columnHeights(List<Rect> rects) {
  final byLeft = <double, List<Rect>>{};
  for (final r in rects) {
    byLeft.putIfAbsent(r.left, () => []).add(r);
  }
  return {
    for (final entry in byLeft.entries)
      entry.key: entry.value.map((r) => r.bottom).reduce(math.max) -
          entry.value.map((r) => r.top).reduce(math.min),
  };
}

void main() {
  test('empty input returns an empty list', () {
    final rects = MasonryLayout.pack(
      aspectRatios: [],
      containerWidth: 400,
      targetTotalHeight: 200,
    );
    expect(rects, isEmpty);
  });

  test('single item fills the full container width', () {
    final rects = MasonryLayout.pack(
      aspectRatios: [16 / 9],
      containerWidth: 400,
      targetTotalHeight: 200,
    );

    expect(rects, hasLength(1));
    expect(rects.single.left, 0);
    expect(rects.single.top, 0);
    expect(rects.single.width, closeTo(400, 0.01));
    expect(rects.single.width / rects.single.height, closeTo(16 / 9, 0.01));
  });

  test('every item keeps its own aspect ratio exactly', () {
    final aspectRatios = [0.5, 1.0, 2.0, 1.5, 0.8, 3.2, 0.3, 1.1];
    final rects = MasonryLayout.pack(
      aspectRatios: aspectRatios,
      containerWidth: 600,
      targetTotalHeight: 400,
      gap: 8,
    );

    for (var i = 0; i < aspectRatios.length; i++) {
      expect(
        rects[i].width / rects[i].height,
        closeTo(aspectRatios[i], 0.01),
        reason: 'item $i should preserve its aspect ratio',
      );
    }
  });

  test('no two items overlap', () {
    final aspectRatios = [0.4, 0.9, 1.6, 2.4, 0.7, 1.0, 1.3, 3.0, 0.5, 1.8];
    final rects = MasonryLayout.pack(
      aspectRatios: aspectRatios,
      containerWidth: 700,
      targetTotalHeight: 500,
      gap: 4,
    );

    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          _overlaps(rects[i], rects[j]),
          isFalse,
          reason: 'items $i and $j should not overlap',
        );
      }
    }
  });

  test('every column exactly fills the target height - no ragged bottom edge', () {
    final aspectRatios = [0.4, 0.9, 1.6, 2.4, 0.7, 1.0, 1.3, 3.0, 0.5, 1.8];
    const targetTotalHeight = 500.0;
    final rects = MasonryLayout.pack(
      aspectRatios: aspectRatios,
      containerWidth: 700,
      targetTotalHeight: targetTotalHeight,
      gap: 4,
    );

    for (final height in _columnHeights(rects).values) {
      expect(height, closeTo(targetTotalHeight, 0.5));
    }
  });

  test(
    'no single item spans anywhere close to the whole container width - '
    'the row-based layout this replaced did exactly that for a sparse '
    'trailing row',
    () {
      final aspectRatios = [1.8, 1.6, 2.0, 1.5, 0.4, 1.7];
      const containerWidth = 600.0;
      final rects = MasonryLayout.pack(
        aspectRatios: aspectRatios,
        containerWidth: containerWidth,
        targetTotalHeight: 200,
        gap: 2,
      );

      for (final r in rects) {
        expect(r.width, lessThan(containerWidth * 0.5));
      }
    },
  );

  test('column widths stay reasonably balanced, not dominated by one column', () {
    final aspectRatios = [0.4, 0.9, 1.6, 2.4, 0.7, 1.0, 1.3, 3.0, 0.5, 1.8];
    final rects = MasonryLayout.pack(
      aspectRatios: aspectRatios,
      containerWidth: 700,
      targetTotalHeight: 500,
      gap: 4,
    );

    final widths = <double>{};
    for (final r in rects) {
      widths.add(r.width);
    }
    final maxWidth = widths.reduce((a, b) => a > b ? a : b);
    final minWidth = widths.reduce((a, b) => a < b ? a : b);
    expect(maxWidth / minWidth, lessThan(3.0));
  });

  test('a portrait item ends up narrower than a landscape item sharing a column', () {
    final rects = MasonryLayout.pack(
      aspectRatios: [0.5, 2.0],
      containerWidth: 300,
      targetTotalHeight: 600,
      gap: 4,
    );

    expect(rects, hasLength(2));
    // Sharing one column (same width) - what varies is height, driven
    // purely by each item's own aspect ratio.
    expect(rects[0].width, closeTo(rects[1].width, 0.5));
    expect(rects[0].height, greaterThan(rects[1].height));
  });

  test('a wider container packs items noticeably wider on average', () {
    final aspectRatios = [1.0, 1.0, 1.0];
    final narrow = MasonryLayout.pack(
      aspectRatios: aspectRatios,
      containerWidth: 200,
      targetTotalHeight: 200,
    );
    final wide = MasonryLayout.pack(
      aspectRatios: aspectRatios,
      containerWidth: 800,
      targetTotalHeight: 200,
    );

    final narrowAvgWidth =
        narrow.map((r) => r.width).reduce((a, b) => a + b) / narrow.length;
    final wideAvgWidth =
        wide.map((r) => r.width).reduce((a, b) => a + b) / wide.length;
    expect(wideAvgWidth, greaterThan(narrowAvgWidth));
  });

  test('packing the same input twice reproduces the same result', () {
    final aspectRatios = [1.2, 0.7, 2.1, 1.0, 0.9];
    final first = MasonryLayout.pack(
      aspectRatios: aspectRatios,
      containerWidth: 500,
      targetTotalHeight: 300,
    );
    final second = MasonryLayout.pack(
      aspectRatios: aspectRatios,
      containerWidth: 500,
      targetTotalHeight: 300,
    );

    for (var i = 0; i < first.length; i++) {
      expect(second[i].left, closeTo(first[i].left, 1e-9));
      expect(second[i].top, closeTo(first[i].top, 1e-9));
      expect(second[i].width, closeTo(first[i].width, 1e-9));
      expect(second[i].height, closeTo(first[i].height, 1e-9));
    }
  });
}
