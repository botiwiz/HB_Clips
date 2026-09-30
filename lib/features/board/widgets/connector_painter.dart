import 'dart:math';

import 'package:flutter/rendering.dart';

/// One connector's curve endpoints/controls and style, already converted
/// by the caller into screen space - the painter itself has no opinion on
/// coordinate systems (same convention as `StrokeSpec`).
class ConnectorSpec {
  final Offset p0;
  final Offset c1;
  final Offset c2;
  final Offset p3;
  final Color color;
  final double width;

  const ConnectorSpec({
    required this.p0,
    required this.c1,
    required this.c2,
    required this.p3,
    required this.color,
    required this.width,
  });
}

class ConnectorPainter extends CustomPainter {
  final List<ConnectorSpec> connectors;

  const ConnectorPainter(this.connectors);

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in connectors) {
      final paint = Paint()
        ..color = c.color
        ..strokeWidth = c.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(c.p0.dx, c.p0.dy)
        ..cubicTo(c.c1.dx, c.c1.dy, c.c2.dx, c.c2.dy, c.p3.dx, c.p3.dy);
      canvas.drawPath(path, paint);
      _drawArrowHead(canvas, c, paint);
    }
  }

  /// Mirrors `StrokePainter._drawArrowHead`'s technique exactly, but the
  /// "from" point is the bezier's own last control point - the tangent
  /// direction at t=1 of a cubic bezier is along p3-c2 - not a polyline's
  /// second-to-last point.
  void _drawArrowHead(Canvas canvas, ConnectorSpec c, Paint paint) {
    final tip = c.p3;
    final direction = tip - c.c2;
    if (direction.distance == 0) return;
    final angle = direction.direction;
    final headLength = 8.0 + c.width * 2;
    const spreadAngle = 0.5;
    for (final sign in [-1, 1]) {
      final wingAngle = angle + pi + sign * spreadAngle;
      final wingEnd = tip + Offset.fromDirection(wingAngle, headLength);
      canvas.drawLine(tip, wingEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ConnectorPainter oldDelegate) => true;
}
