import 'package:flutter/rendering.dart';

/// One connector's orthogonal route and style, already converted by the
/// caller into screen space - the painter itself has no opinion on
/// coordinate systems (same convention as `StrokeSpec`). [points] is the
/// route's straight-segment polyline (see `ConnectorGeometry.routeBoard`),
/// drawn with sharp (mitered) corners - the app's sharp-corner design.
/// Callers pass the accent color for [color] when this connector is
/// selected, same "caller decides color" convention as everywhere else
/// in this file.
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

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in connectors) {
      if (c.points.isEmpty) continue;
      final paint = Paint()
        ..color = c.color
        ..strokeWidth = c.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.miter
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(c.points.first.dx, c.points.first.dy);
      for (final point in c.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
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
