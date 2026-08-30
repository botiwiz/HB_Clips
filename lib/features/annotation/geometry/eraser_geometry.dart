import 'package:flutter/rendering.dart';

/// Pure geometry for the eraser tool - no widget imports, unit-testable
/// like `selection_geometry.dart`/`crop_geometry.dart`.
class EraserGeometry {
  EraserGeometry._();

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - projection).distance;
  }

  /// True if [point] comes within [maxDistance] of any segment of the
  /// polyline described by [points] (in the same coordinate space as
  /// [point] - callers are responsible for consistent units/space).
  static bool strokeNearPoint(
    List<Offset> points,
    Offset point,
    double maxDistance,
  ) {
    if (points.isEmpty) return false;
    if (points.length == 1) {
      return (point - points.first).distance <= maxDistance;
    }
    for (var i = 0; i < points.length - 1; i++) {
      if (_distanceToSegment(point, points[i], points[i + 1]) <=
          maxDistance) {
        return true;
      }
    }
    return false;
  }
}
