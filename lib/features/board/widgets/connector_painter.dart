import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// One connector's orthogonal route and style, already converted by the
/// caller into screen space - the painter itself has no opinion on
/// coordinate systems (same convention as `StrokeSpec`). [points] is the
/// route's straight-segment polyline (see `ConnectorGeometry.routeBoard`);
/// corners get rounded at paint time to [cornerRadius] (already
/// screen-space, `kConnectorCornerRadius * view.scale` - same "caller
/// scales world units to screen pixels" convention [width] already
/// follows). Callers pass the accent color for [color] when this
/// connector is selected, same "caller decides color" convention as
/// everywhere else in this file.
class ConnectorSpec {
  final List<Offset> points;
  final Color color;
  final double width;
  final double cornerRadius;

  const ConnectorSpec({
    required this.points,
    required this.color,
    required this.width,
    required this.cornerRadius,
  });
}

class ConnectorPainter extends CustomPainter {
  final List<ConnectorSpec> connectors;

  const ConnectorPainter(this.connectors);

  static const double _endpointRadius = 4;

  /// Builds a straight-segment path through [points] with each interior
  /// vertex rounded off to [radius] - the standard "rounded polyline
  /// corner" technique: stop short of the vertex by [radius] along each
  /// adjacent segment, then join those two stop points with a quadratic
  /// Bezier using the sharp vertex itself as the control point (tangent
  /// to both segments). [radius] is clamped per-corner to at most half
  /// the shorter of its two adjacent segments, so a short stub never
  /// produces an overshooting/self-intersecting curve.
  static Path _roundedPath(List<Offset> points, double radius) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length < 3) {
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      return path;
    }
    for (var i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final v = points[i];
      final next = points[i + 1];
      final toPrev = prev - v;
      final toNext = next - v;
      final prevLen = toPrev.distance;
      final nextLen = toNext.distance;
      final r = radius.clamp(0.0, math.min(prevLen, nextLen) / 2);
      final start = v + toPrev * (r / (prevLen == 0 ? 1 : prevLen));
      final end = v + toNext * (r / (nextLen == 0 ? 1 : nextLen));
      path.lineTo(start.dx, start.dy);
      path.quadraticBezierTo(v.dx, v.dy, end.dx, end.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in connectors) {
      if (c.points.isEmpty) continue;
      final paint = Paint()
        ..color = c.color
        ..strokeWidth = c.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(_roundedPath(c.points, c.cornerRadius), paint);
      canvas.drawCircle(
        c.points.last,
        _endpointRadius,
        Paint()
          ..color = c.color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConnectorPainter oldDelegate) => true;
}
