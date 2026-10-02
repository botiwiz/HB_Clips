import 'package:flutter/material.dart';

/// Paints pre-computed rounded-rect highlight boxes (see
/// `HighlightGeometry.rectsFor`) behind a text widget - a sibling earlier
/// in the same `Stack`, not a decoration on the text itself, since
/// `TextStyle.backgroundColor` can't be rounded.
class HighlightPainter extends CustomPainter {
  final List<RRect> rects;
  final Color color;

  const HighlightPainter({required this.rects, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final rect in rects) {
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant HighlightPainter oldDelegate) {
    return color != oldDelegate.color ||
        rects.length != oldDelegate.rects.length ||
        !_rectsEqual(rects, oldDelegate.rects);
  }

  static bool _rectsEqual(List<RRect> a, List<RRect> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
