import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Packs a list of items (given only by their aspect ratio) into rows that
/// exactly fill a target width, each row's height computed so its items'
/// scaled widths plus gaps sum to that width exactly - the classic
/// "justified gallery" technique (Google Photos/Flickr-style), so every
/// item keeps its own aspect ratio with no letterboxing/cropping and no
/// gaps or overflow within a row. Pure math, no widget imports - unit
/// tested directly in `test/features/board/justified_layout_test.dart`.
class JustifiedLayout {
  JustifiedLayout._();

  /// Row height is never allowed to collapse below this fraction of the
  /// current target row-height guess, guarding against a single
  /// extreme-aspect-ratio item forcing a sliver row.
  static const double _minRowHeightFactor = 0.4;

  static const int _searchIterations = 6;

  /// Packs [aspectRatios] (width/height, one per item, same order the
  /// caller's items are in) into rows filling [containerWidth] exactly.
  /// [targetTotalHeight] only seeds the initial row-height guess and a
  /// bounded search to keep the packed result's total height close to it -
  /// the final total height is an emergent result, not forced to match
  /// exactly (over-constrained once every item's aspect ratio must be kept
  /// and every row must fill the width exactly).
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
    final originalArea = targetTotalHeight * containerWidth;
    // If everything were laid out in one unbroken row at height h, its
    // total width would be h * sumAspect and total area h^2 * sumAspect -
    // solving that for h given the target area is the starting guess.
    var guess = originalArea > 0 && sumAspect > 0
        ? math.sqrt(originalArea / sumAspect).clamp(1.0, double.infinity)
        : containerWidth / aspectRatios.length;

    List<Rect> layout = _layoutAt(aspectRatios, containerWidth, guess, gap);

    // Bounded binary search on the row-height guess to bring the resulting
    // total height close to targetTotalHeight, without ever forcing an
    // exact match (see class doc).
    var lo = guess * 0.1;
    var hi = guess * 10;
    for (var i = 0; i < _searchIterations; i++) {
      final resultHeight = _totalHeight(layout, gap);
      if ((resultHeight - targetTotalHeight).abs() < 0.5) break;
      if (resultHeight > targetTotalHeight) {
        hi = guess;
      } else {
        lo = guess;
      }
      guess = (lo + hi) / 2;
      layout = _layoutAt(aspectRatios, containerWidth, guess, gap);
    }

    return layout;
  }

  static double _totalHeight(List<Rect> layout, double gap) {
    if (layout.isEmpty) return 0;
    final rowTops = <double>{};
    for (final r in layout) {
      rowTops.add(r.top);
    }
    final sortedTops = rowTops.toList()..sort();
    final lastRowRects = layout.where((r) => r.top == sortedTops.last);
    final lastRowHeight = lastRowRects.map((r) => r.height).reduce(
      (a, b) => a > b ? a : b,
    );
    return sortedTops.last + lastRowHeight;
  }

  static List<Rect> _layoutAt(
    List<double> aspectRatios,
    double containerWidth,
    double targetRowHeight,
    double gap,
  ) {
    final rects = List<Rect?>.filled(aspectRatios.length, null);
    var rowStart = 0;
    var y = 0.0;

    void closeRow(int rowEnd) {
      final count = rowEnd - rowStart;
      final rowAspectSum = aspectRatios
          .sublist(rowStart, rowEnd)
          .fold<double>(0, (a, b) => a + b);
      final availableWidth = containerWidth - (count - 1) * gap;
      var rowHeight = rowAspectSum > 0
          ? availableWidth / rowAspectSum
          : targetRowHeight;
      final minHeight = targetRowHeight * _minRowHeightFactor;
      if (rowHeight < minHeight) rowHeight = minHeight;

      var x = 0.0;
      for (var i = rowStart; i < rowEnd; i++) {
        final width = rowHeight * aspectRatios[i];
        rects[i] = Rect.fromLTWH(x, y, width, rowHeight);
        x += width + gap;
      }
      y += rowHeight + gap;
    }

    var runningAspect = 0.0;
    var runningCount = 0;
    for (var i = 0; i < aspectRatios.length; i++) {
      final candidateAspect = runningAspect + aspectRatios[i];
      final candidateCount = runningCount + 1;
      final candidateWidth =
          candidateAspect * targetRowHeight + (candidateCount - 1) * gap;
      if (candidateWidth > containerWidth && runningCount > 0) {
        closeRow(i);
        rowStart = i;
        runningAspect = aspectRatios[i];
        runningCount = 1;
      } else {
        runningAspect = candidateAspect;
        runningCount = candidateCount;
      }
    }
    closeRow(aspectRatios.length);

    return rects.cast<Rect>();
  }
}
