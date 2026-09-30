import 'package:flutter/rendering.dart';

/// One connector's curve endpoints/controls and style, already converted
/// by the caller into screen space - the painter itself has no opinion on
/// coordinate systems (same convention as `StrokeSpec`). Callers pass the
/// accent color for [color] when this connector is selected, same
/// "caller decides color" convention as everywhere else in this file.
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

  static const double _endpointRadius = 4;

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
      canvas.drawCircle(
        c.p3,
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
