import 'package:flutter/rendering.dart';

import '../../../core/constants.dart' show kConnectorCornerRadius;
import '../geometry/connector_geometry.dart';

/// One connector's orthogonal route and style, already converted by the
/// caller into screen space - the painter itself has no opinion on
/// coordinate systems (same convention as `StrokeSpec`). [points] is the
/// route's straight-segment polyline (see `ConnectorGeometry.routeBoard`);
/// its interior vertices get rounded at paint time (see
/// `ConnectorGeometry.cornerRadii`), the radius clamped down per corner
/// so it can never overshoot regardless of how short a segment is or how
/// zoomed-in/out the board currently is. Callers pass the accent color
/// for [color] when this connector is selected, same "caller decides
/// color" convention as everywhere else in this file.
class ConnectorSpec {
  final List<Offset> points;
  final Color color;
  final double width;

  const ConnectorSpec({
    required this.points,
    required this.color,
    required this.width,
  });
}

class ConnectorPainter extends CustomPainter {
  final List<ConnectorSpec> connectors;

  const ConnectorPainter(this.connectors);

  static const double _endpointRadius = 4;

  /// Builds a straight-segment path through [points] with every interior
  /// vertex rounded off per its own entry in [radii] (parallel array -
  /// see `ConnectorGeometry.cornerRadii`; already safely clamped, no
  /// clamping happens here). Standard "rounded polyline corner" trick:
  /// stop short of the vertex by its own radius along each adjacent
  /// segment, then join those two stop points with a quadratic Bezier
  /// using the sharp vertex itself as the control point - tangent to
  /// both segments, and (since a quadratic Bezier never leaves the
  /// triangle formed by its three control points) geometrically
  /// incapable of overshooting past the vertex or either stop point,
  /// whatever the radius.
  static Path _roundedPath(List<Offset> points, List<double> radii) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final v = points[i];
      final r = radii[i];
      if (r <= 0) {
        path.lineTo(v.dx, v.dy);
        continue;
      }
      final toPrev = points[i - 1] - v;
      final toNext = points[i + 1] - v;
      final start = v + toPrev * (r / toPrev.distance);
      final end = v + toNext * (r / toNext.distance);
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
      final radii = ConnectorGeometry.cornerRadii(
        c.points,
        kConnectorCornerRadius,
      );
      canvas.drawPath(_roundedPath(c.points, radii), paint);
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
