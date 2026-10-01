import 'package:flutter/rendering.dart';

import '../../../data/models/clip.dart';

/// Pure geometry for vector shape primitives - no widget imports, unit
/// tested directly (see test/features/board/shape_geometry_test.dart),
/// same convention as ClipGeometry/ConnectorGeometry. Every shape is
/// defined purely as a function of its bounding box, in local unrotated
/// space `(0,0)-(size.width,size.height)` - the caller (board_canvas.dart's
/// Positioned+Transform.rotate wrapping) already handles position/rotation
/// for any clip type, so shapes get that for free.
class ShapeGeometry {
  ShapeGeometry._();

  /// Local-space, unrotated closed-polygon outline for [kind] at [size].
  /// Ellipse has no polygon form - use [pathFor] directly for that case
  /// (an inscribed oval, not a polygon).
  static List<Offset> polygonVertices(ShapeKind kind, Size size) {
    final w = size.width;
    final h = size.height;
    return switch (kind) {
      ShapeKind.rectangle => [
        Offset(0, 0),
        Offset(w, 0),
        Offset(w, h),
        Offset(0, h),
      ],
      ShapeKind.triangle => [Offset(w / 2, 0), Offset(w, h), Offset(0, h)],
      // draw.io-style basic trapezoid: top edge inset ~18% per side, bottom
      // edge full width.
      ShapeKind.trapezoid => [
        Offset(w * 0.18, 0),
        Offset(w * 0.82, 0),
        Offset(w, h),
        Offset(0, h),
      ],
      // Top edge shifted right by ~20% of width, both verticals slanted the
      // same direction.
      ShapeKind.parallelogram => [
        Offset(w * 0.20, 0),
        Offset(w, 0),
        Offset(w * 0.80, h),
        Offset(0, h),
      ],
      ShapeKind.ellipse => throw ArgumentError(
        'ellipse has no polygon form; use ShapeGeometry.pathFor instead',
      ),
    };
  }

  static bool isEllipse(ShapeKind kind) => kind == ShapeKind.ellipse;

  /// The closed [Path] for [kind] at [size] - the single source of truth
  /// `ShapePainter` draws from, so rendering and (any future precise)
  /// hit-testing can never disagree.
  static Path pathFor(ShapeKind kind, Size size) {
    if (isEllipse(kind)) {
      return Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    final vertices = polygonVertices(kind, size);
    return Path()..addPolygon(vertices, true);
  }
}
