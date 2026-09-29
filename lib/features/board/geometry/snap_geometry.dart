import 'package:flutter/rendering.dart';

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
  /// every candidate - a drag can snap on X, Y, both, or neither. Returns
  /// [delta] unadjusted on whichever axis has no candidate within
  /// [threshold].
  static Offset snapDelta({
    required Rect draggedBoundsBeforeDelta,
    required Offset delta,
    required List<Rect> others,
    required double threshold,
  }) {
    final dragged = draggedBoundsBeforeDelta.shift(delta);

    var bestDx = 0.0;
    var bestDxDist = threshold;
    var bestDy = 0.0;
    var bestDyDist = threshold;

    for (final other in others) {
      for (final edge in [dragged.left, dragged.right]) {
        for (final target in [other.left, other.right]) {
          final dist = (edge - target).abs();
          if (dist < bestDxDist) {
            bestDxDist = dist;
            bestDx = target - edge;
          }
        }
      }
      for (final edge in [dragged.top, dragged.bottom]) {
        for (final target in [other.top, other.bottom]) {
          final dist = (edge - target).abs();
          if (dist < bestDyDist) {
            bestDyDist = dist;
            bestDy = target - edge;
          }
        }
      }
    }

    return Offset(delta.dx + bestDx, delta.dy + bestDy);
  }
}
