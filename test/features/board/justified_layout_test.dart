import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/geometry/justified_layout.dart';

void main() {
  test('single item fills the full container width', () {
    final rects = JustifiedLayout.pack(
      aspectRatios: [16 / 9],
      containerWidth: 400,
      targetTotalHeight: 200,
    );

    expect(rects, hasLength(1));
    expect(rects.single.left, 0);
    expect(rects.single.top, 0);
    expect(rects.single.width, closeTo(400, 0.01));
    expect(
      rects.single.width / rects.single.height,
      closeTo(16 / 9, 0.01),
    );
  });

  test('same-aspect-ratio items produce a uniform grid', () {
    final rects = JustifiedLayout.pack(
      aspectRatios: List.filled(6, 1.0), // 6 squares
      containerWidth: 300,
      targetTotalHeight: 200,
      gap: 10,
    );

    expect(rects, hasLength(6));
    final widths = rects.map((r) => r.width).toSet();
    final heights = rects.map((r) => r.height).toSet();
    // Every square should end up the same size as every other one in its
    // row, and rows should share a height too since every aspect ratio is
    // identical.
    expect(widths.length, lessThanOrEqualTo(2));
    expect(heights.length, lessThanOrEqualTo(2));
    for (final r in rects) {
      expect(r.width, closeTo(r.height, 0.01));
    }
  });

  test('every row exactly fills the container width', () {
    final aspectRatios = [1.0, 2.5, 0.6, 1.2, 1.8, 0.9, 1.0, 3.0, 0.5];
    const containerWidth = 500.0;
    const gap = 12.0;
    final rects = JustifiedLayout.pack(
      aspectRatios: aspectRatios,
      containerWidth: containerWidth,
      targetTotalHeight: 300,
      gap: gap,
    );

    // Group rects by row (shared `top`).
    final byTop = <double, List<Rect>>{};
    for (final r in rects) {
      byTop.putIfAbsent(r.top, () => []).add(r);
    }

    for (final row in byTop.values) {
      final totalWidth =
          row.fold<double>(0, (a, r) => a + r.width) + (row.length - 1) * gap;
      expect(totalWidth, closeTo(containerWidth, 0.5));
    }
  });

  test('every item keeps its own aspect ratio', () {
    final aspectRatios = [0.5, 1.0, 2.0, 1.5, 0.8, 3.2];
    final rects = JustifiedLayout.pack(
      aspectRatios: aspectRatios,
      containerWidth: 600,
      targetTotalHeight: 250,
    );

    for (var i = 0; i < aspectRatios.length; i++) {
      expect(
        rects[i].width / rects[i].height,
        closeTo(aspectRatios[i], 0.01),
        reason: 'item $i should preserve its aspect ratio',
      );
    }
  });

  test('an extreme aspect ratio does not collapse its row to a sliver', () {
    final rects = JustifiedLayout.pack(
      aspectRatios: [1.0, 1.0, 20.0, 1.0, 1.0],
      containerWidth: 400,
      targetTotalHeight: 200,
    );

    for (final r in rects) {
      expect(r.height, greaterThan(1));
    }
  });

  test('resulting total height lands close to the target for a typical case', () {
    final rects = JustifiedLayout.pack(
      aspectRatios: [1.0, 1.5, 0.8, 1.2, 1.0, 0.9, 1.3, 1.1],
      containerWidth: 500,
      targetTotalHeight: 300,
    );

    final totalHeight = rects
        .map((r) => r.top + r.height)
        .reduce((a, b) => a > b ? a : b);
    expect((totalHeight - 300).abs(), lessThan(300 * 0.35));
  });

  test('empty input returns an empty list', () {
    final rects = JustifiedLayout.pack(
      aspectRatios: [],
      containerWidth: 400,
      targetTotalHeight: 200,
    );
    expect(rects, isEmpty);
  });
}
