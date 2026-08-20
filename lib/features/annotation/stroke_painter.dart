import 'package:flutter/rendering.dart';

/// One stroke's points, color and width, already converted by the caller
/// into whatever coordinate space this painter's canvas covers (screen
/// space for freestanding strokes, local box-pixel space for per-clip
/// strokes) - the painter itself has no opinion on coordinate systems.
class StrokeSpec {
  final List<Offset> points;
  final Color color;
  final double width;

  const StrokeSpec({
    required this.points,
    required this.color,
    required this.width,
  });
}

Color hexToColor(String hex) {
  final digits = hex.replaceFirst('#', '');
  return Color(int.parse('FF$digits', radix: 16));
}

class StrokePainter extends CustomPainter {
  final List<StrokeSpec> strokes;

  const StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) => true;
}
