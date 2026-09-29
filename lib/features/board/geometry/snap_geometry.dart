import 'package:flutter/rendering.dart';

/// Result of [SnapGeometry.snap]: the adjusted drag delta, plus the
/// board-space coordinate of whichever edge(s) it snapped to - if any - so
/// the caller can draw a "smart guide" line there (see
/// `SnapGuidesOverlay`). Null on an axis means nothing snapped on that
/// axis.
class SnapResult {
  final Offset delta;
  final double? guideX;
  final double? guideY;

  const SnapResult({required this.delta, this.guideX, this.guideY});
}

/// Result of [SnapGeometry.snapPoint]: the adjusted point, plus the
/// board-space coordinate of whichever edge(s) it snapped to - if any.
/// Null on an axis means nothing snapped on that axis.
class PointSnapResult {
  final Offset point;
  final double? guideX;
  final double? guideY;

  const PointSnapResult({required this.point, this.guideX, this.guideY});
}

/// Pure geometry for "smart guide" edge-alignment snapping while dragging a
/// selection - a distinct concern from the existing grid-snap toggle
/// (`ClipGeometry.snap`), since this snaps to *other elements'* edges
/// rather than a fixed grid. No widget imports - unit tested directly in
/// `test/features/board/snap_geometry_test.dart`.
class SnapGeometry {
  SnapGeometry._();

  /// Adjusts [delta] so the dragged selection's bounding box - starting
  /// from [draggedBoundsBeforeDelta] and shifted by [delta] - has a left or
  /// right edge aligning exactly with the nearest left or right edge of any
  /// rect in [others], and independently the same for top/bottom, if one is
  /// within [threshold] board units on that axis. Each axis snaps to
  /// whichever single (dragged edge, other edge) pair is closest across
  /// every candidate - a drag can snap on X, Y, both, or neither. The
  /// returned delta is unadjusted on whichever axis has no candidate within
  /// [threshold], and that axis's guide coordinate is null.
  static SnapResult snap({
    required Rect draggedBoundsBeforeDelta,
    required Offset delta,
    required List<Rect> others,
    required double threshold,
  }) {
    final dragged = draggedBoundsBeforeDelta.shift(delta);

    var bestDx = 0.0;
    var bestDxDist = threshold;
    double? guideX;
    var bestDy = 0.0;
    var bestDyDist = threshold;
    double? guideY;

    for (final other in others) {
      for (final edge in [dragged.left, dragged.right]) {
        for (final target in [other.left, other.right]) {
          final dist = (edge - target).abs();
          if (dist < bestDxDist) {
            bestDxDist = dist;
            bestDx = target - edge;
            guideX = target;
          }
        }
      }
      for (final edge in [dragged.top, dragged.bottom]) {
        for (final target in [other.top, other.bottom]) {
          final dist = (edge - target).abs();
          if (dist < bestDyDist) {
            bestDyDist = dist;
            bestDy = target - edge;
            guideY = target;
          }
        }
      }
    }

    return SnapResult(
      delta: Offset(delta.dx + bestDx, delta.dy + bestDy),
      guideX: guideX,
      guideY: guideY,
    );
  }

  /// Snaps [point] - the free corner being dragged while resizing a single
  /// clip or scaling a group (the opposite corner stays anchored) - so its
  /// x aligns with the nearest left/right edge of any rect in [others],
  /// and independently its y aligns with the nearest top/bottom edge, each
  /// within [threshold] board units. Unlike [snap], there's no whole
  /// dragged-rect bounding box here - the moving corner *is* both free
  /// edges' intersection, so each axis snaps directly off the point
  /// itself.
  static PointSnapResult snapPoint({
    required Offset point,
    required List<Rect> others,
    required double threshold,
  }) {
    var bestX = point.dx;
    var bestXDist = threshold;
    double? guideX;
    var bestY = point.dy;
    var bestYDist = threshold;
    double? guideY;

    for (final other in others) {
      for (final target in [other.left, other.right]) {
        final dist = (point.dx - target).abs();
        if (dist < bestXDist) {
          bestXDist = dist;
          bestX = target;
          guideX = target;
        }
      }
      for (final target in [other.top, other.bottom]) {
        final dist = (point.dy - target).abs();
        if (dist < bestYDist) {
          bestYDist = dist;
          bestY = target;
          guideY = target;
        }
      }
    }

    return PointSnapResult(
      point: Offset(bestX, bestY),
      guideX: guideX,
      guideY: guideY,
    );
  }
}
