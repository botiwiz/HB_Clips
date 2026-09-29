import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Packs items (given only by aspect ratio) into a Pinterest-style masonry
/// grid: fixed-width columns, each item's height following its own aspect
/// ratio at that width - never distorted, and never forced to share a
/// row's height with unrelated items the way a row-based "justified
/// gallery" layout does. That row-based approach (this class's
/// predecessor) had a real problem: a sparse trailing row - as few as one
/// item - got stretched alone to fill the entire container width by
/// itself, ballooning it (especially a portrait item, whose small aspect
/// ratio demands a huge height to fill that width). Masonry has no
/// equivalent failure mode, since every item's size is fully determined by
/// its own aspect ratio and the shared column width, independent of how
/// many other items happen to be nearby.
///
/// Items are placed into whichever column is currently shortest (the
/// classic masonry heuristic), which naturally balances column heights
/// over time. Since height = columnWidth / aspectRatio, a portrait item
/// (small aspect ratio) naturally ends up taller - filling more vertical
/// space - while a landscape item (large aspect ratio) ends up shorter -
/// filling less. Combined with shortest-column-first placement, this
/// means multiple items' sizes vary to suit whatever space they land in,
/// as an emergent property of the layout rather than a bolted-on special
/// case for one item.
///
/// Pure math, no widget imports - unit tested directly in
/// `test/features/board/masonry_layout_test.dart`.
class MasonryLayout {
  MasonryLayout._();

  /// How many column counts on either side of the aspect-driven initial
  /// guess to also try, keeping whichever lands closest to the target
  /// total height - column count is a discrete choice (unlike a
  /// continuous row height), so a small bounded search around the guess is
  /// cheap and gets closer than the guess alone.
  static const int _columnSearchRadius = 2;

  /// Packs [aspectRatios] (width/height, one per item, same order the
  /// caller's items are in) into columns filling [containerWidth].
  /// [targetTotalHeight] only seeds the initial column-count guess and a
  /// small bounded search to keep the result's total height close to it -
  /// the final total height is an emergent result of the chosen column
  /// count and each item's own aspect ratio, not forced to match exactly.
  ///
  /// Returns one [Rect] per input item, in the same order, positioned from
  /// origin (0,0) - the caller offsets by wherever the packed block should
  /// actually sit on the board.
  static List<Rect> pack({
    required List<double> aspectRatios,
    required double containerWidth,
    required double targetTotalHeight,
    double gap = 16,
  }) {
    if (aspectRatios.isEmpty) return const [];

    final sumAspect = aspectRatios.fold<double>(0, (a, b) => a + b);
    final avgAspect = sumAspect / aspectRatios.length;
    // If every column were populated with a proportional share of the
    // items, all averaging avgAspect, its height would land at roughly
    // (count/columns) * ((containerWidth/columns) / avgAspect). Setting
    // that equal to targetTotalHeight and solving for columns gives a
    // reasonable starting guess to search around.
    final guessColumns = targetTotalHeight > 0 && avgAspect > 0
        ? math
              .sqrt(
                aspectRatios.length *
                    containerWidth /
                    (avgAspect * targetTotalHeight),
              )
              .round()
              .clamp(1, aspectRatios.length)
        : 1;

    List<Rect>? best;
    var bestHeightDiff = double.infinity;
    final lo = math.max(1, guessColumns - _columnSearchRadius);
    final hi = math.min(aspectRatios.length, guessColumns + _columnSearchRadius);
    for (var columns = lo; columns <= hi; columns++) {
      final layout = _layoutColumns(aspectRatios, containerWidth, columns, gap);
      final height = layout.map((r) => r.bottom).reduce(math.max);
      final diff = (height - targetTotalHeight).abs();
      if (diff < bestHeightDiff) {
        bestHeightDiff = diff;
        best = layout;
      }
    }
    return best!;
  }

  static List<Rect> _layoutColumns(
    List<double> aspectRatios,
    double containerWidth,
    int columns,
    double gap,
  ) {
    final columnWidth = (containerWidth - (columns - 1) * gap) / columns;
    final columnHeights = List<double>.filled(columns, 0);
    final rects = <Rect>[];

    for (final aspectRatio in aspectRatios) {
      // Shortest-column-first: the classic masonry placement heuristic -
      // naturally balances column heights as items are placed.
      var shortest = 0;
      for (var i = 1; i < columns; i++) {
        if (columnHeights[i] < columnHeights[shortest]) shortest = i;
      }
      final height = columnWidth / aspectRatio;
      final x = shortest * (columnWidth + gap);
      final y = columnHeights[shortest];
      rects.add(Rect.fromLTWH(x, y, columnWidth, height));
      columnHeights[shortest] = y + height + gap;
    }
    return rects;
  }
}
