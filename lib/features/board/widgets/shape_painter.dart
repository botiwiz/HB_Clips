import 'package:flutter/material.dart';

import '../../../data/models/clip.dart';
import '../geometry/shape_geometry.dart';

/// Draws one vector shape clip's fill + stroke from its [ShapeKind] and
/// box [size] - the single rendering path reused for on-board clips, the
/// shape-picker's thumbnail icons, and the placement drag-preview, so all
/// three are guaranteed pixel-consistent with each other.
class ShapePainter extends CustomPainter {
  final ShapeKind kind;

  /// Null means no fill (outline-only shape).
  final Color? fillColor;

  /// Null means no stroke is drawn at all.
  final Color? strokeColor;
  final double strokeWidth;

  const ShapePainter({
    required this.kind,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = ShapeGeometry.pathFor(kind, size);
    final fill = fillColor;
    if (fill != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = fill
          ..style = PaintingStyle.fill,
      );
    }
    final stroke = strokeColor;
    if (stroke != null && strokeWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) =>
      kind != oldDelegate.kind ||
      fillColor != oldDelegate.fillColor ||
      strokeColor != oldDelegate.strokeColor ||
      strokeWidth != oldDelegate.strokeWidth;
}
