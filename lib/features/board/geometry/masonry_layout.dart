import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Packs items (given only by aspect ratio) into variable-width columns
/// that together exactly fill a `containerWidth` x `targetTotalHeight`
/// rectangle - no ragged bottom edge, no letterboxing. This is the
/// row-based "justified gallery" technique this class's predecessor used
/// (`JustifiedLayout`, since removed), transposed onto columns instead of
/// rows: there, every *row*'s height was solved so its items' widths
/// summed to the container width exactly, stacking rows to approximate
/// the target height; here, every *column*'s width is solved so its
/// items' heights stack to the target height *exactly*, side-by-side
/// columns summing to as close to the container width as the available
/// column-count choices allow. Every item keeps its own aspect ratio
/// exactly - a column's width is shared by every item in it, but each
/// item's height still follows from its own aspect ratio at that width.
///
/// A column's width is `availableHeight / (sum of 1/aspectRatio for its
/// items)` - so items are assigned to whichever column currently has the
/// *smallest* accumulated 1/aspectRatio sum (not the fewest items), the
/// same "shortest column first" idea real masonry grids use, but
/// balancing the quantity that actually drives width instead of a raw
/// item count. This is what keeps multiple items' sizes varying to suit
/// the space rather than one item dominating: a lone portrait item (large
/// 1/aspectRatio) ends up alone in a narrower column, while several
/// landscape items (each a small 1/aspectRatio) cluster together into a
/// column of comparable width - and it directly guards the predecessor's
/// row-based approach's known failure mode, where a sparse trailing group
/// was forced to stretch alone to exactly fill the target: here, no
/// column's accumulated sum can end up wildly smaller than its neighbors',
/// since every new item goes wherever the sum is currently smallest.
///
/// Pure math, no widget imports - unit tested directly in
/// `test/features/board/masonry_layout_test.dart`.
class MasonryLayout {
  MasonryLayout._();

  /// Packs [aspectRatios] (width/height, one per item, same order the
  /// caller's items are in) into columns whose stacked items exactly fill
  /// [targetTotalHeight], trying every column count from 1 to the item
  /// count and keeping whichever lands closest to [containerWidth].
  /// Returns one [Rect] per input item, in the same order, positioned from
  /// origin (0,0) - the caller offsets by wherever the packed block should
  /// actually sit on the board.
  static List<Rect> pack({
    required List<double> aspectRatios,
    required double containerWidth,
    required double targetTotalHeight,
    double gap = 16,
  }) {
    final n = aspectRatios.length;
    if (n == 0) return const [];
    if (n == 1) {
      final height = containerWidth / aspectRatios.single;
      return [Rect.fromLTWH(0, 0, containerWidth, height)];
    }

    List<Rect>? best;
    var bestWidthDiff = double.infinity;
    for (var columns = 1; columns <= n; columns++) {
      final layout = _layoutColumns(aspectRatios, targetTotalHeight, columns, gap);
      final width = _totalWidth(layout);
      final diff = (width - containerWidth).abs();
      if (diff < bestWidthDiff) {
        bestWidthDiff = diff;
        best = layout;
      }
    }
    return best!;
  }

  static double _totalWidth(List<Rect> layout) {
    if (layout.isEmpty) return 0;
    return layout.map((r) => r.right).reduce(math.max);
  }

  static List<Rect> _layoutColumns(
    List<double> aspectRatios,
    double targetTotalHeight,
    int columns,
    double gap,
  ) {
    final n = aspectRatios.length;
    final groups = List.generate(columns, (_) => <int>[]);
    final inverseAspectSums = List<double>.filled(columns, 0);

    for (var i = 0; i < n; i++) {
      var smallest = 0;
      for (var c = 1; c < columns; c++) {
        if (inverseAspectSums[c] < inverseAspectSums[smallest]) smallest = c;
      }
      groups[smallest].add(i);
      inverseAspectSums[smallest] += 1 / aspectRatios[i];
    }

    final rects = List<Rect?>.filled(n, null);
    var x = 0.0;
    for (var c = 0; c < columns; c++) {
      final group = groups[c];
      if (group.isEmpty) continue;
      final availableHeight = targetTotalHeight - (group.length - 1) * gap;
      final columnWidth = inverseAspectSums[c] > 0
          ? availableHeight / inverseAspectSums[c]
          : targetTotalHeight;

      var y = 0.0;
      for (final i in group) {
        final height = columnWidth / aspectRatios[i];
        rects[i] = Rect.fromLTWH(x, y, columnWidth, height);
        y += height + gap;
      }
      x += columnWidth + gap;
    }

    return rects.cast<Rect>();
  }
}
