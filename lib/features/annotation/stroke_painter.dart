import 'dart:math';

import 'package:flutter/rendering.dart';

/// One stroke's points, color and width, already converted by the caller
/// into whatever coordinate space this painter's canvas covers (screen
/// space for freestanding strokes, local box-pixel space for per-clip
/// strokes) - the painter itself has no opinion on coordinate systems.
class StrokeSpec {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool dashed;
  final bool arrowEnd;

  const StrokeSpec({
    required this.points,
    required this.color,
    required this.width,
    this.dashed = false,
    this.arrowEnd = false,
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
      if (stroke.dashed) {
        _drawDashedPath(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
      if (stroke.arrowEnd) {
        _drawArrowHead(canvas, stroke, paint);
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLength = 8.0;
    const gapLength = 6.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
    }
  }

  void _drawArrowHead(Canvas canvas, StrokeSpec stroke, Paint paint) {
    final tip = stroke.points.last;
    final from = stroke.points[stroke.points.length - 2];
    final direction = tip - from;
    if (direction.distance == 0) return;
    final angle = direction.direction;
    final headLength = 8.0 + stroke.width * 2;
    const spreadAngle = 0.5;
    for (final sign in [-1, 1]) {
      final wingAngle = angle + pi + sign * spreadAngle;
      final wingEnd = tip + Offset.fromDirection(wingAngle, headLength);
      canvas.drawLine(tip, wingEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) => true;
}
