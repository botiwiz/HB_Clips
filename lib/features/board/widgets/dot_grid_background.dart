import 'package:flutter/rendering.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/board_controller.dart';

/// Miro-style infinite dot grid: dots live in board space (fixed spacing
/// there), so they scroll with pan and their on-screen spacing scales with
/// zoom - "the grid is a property of the world," not the screen. Only the
/// dots inside the current viewport are ever computed, so this stays cheap
/// regardless of how far the board has been panned.
class DotGridPainter extends CustomPainter {
  final BoardViewState view;

  const DotGridPainter(this.view);

  static const double _boardSpacing = kBoardGridSpacing;
  static const double _baseDotRadius = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = view.scale;

    // Below a certain zoom-out level, a fixed 32px grid would be so dense
    // on screen it reads as solid fog - thin it out (and fade it) instead
    // of ever fully hiding it.
    var stride = 1;
    var opacity = 1.0;
    if (scale < 0.6) {
      stride = scale < 0.25
          ? 4
          : scale < 0.4
          ? 2
          : 1;
      opacity = ((scale - 0.15) / (0.6 - 0.15)).clamp(0.35, 1.0);
    }

    final spacing = _boardSpacing * stride;
    final topLeftBoard = -view.panOffset / scale;
    final bottomRightBoard =
        (Offset(size.width, size.height) - view.panOffset) / scale;

    final startCol = (topLeftBoard.dx / spacing).floor();
    final endCol = (bottomRightBoard.dx / spacing).ceil();
    final startRow = (topLeftBoard.dy / spacing).floor();
    final endRow = (bottomRightBoard.dy / spacing).ceil();

    // Never let dots shrink below a screen-visible size, even at the
    // board's most zoomed-out level - otherwise they round down to
    // sub-pixel and the grid effectively (not just intentionally) vanishes.
    final radius = (_baseDotRadius * scale).clamp(1.0, 6.0);
    final paint = Paint()..color = AppTheme.gridDot.withValues(alpha: 0.5 * opacity);

    for (var col = startCol; col <= endCol; col++) {
      final sx = col * spacing * scale + view.panOffset.dx;
      for (var row = startRow; row <= endRow; row++) {
        final sy = row * spacing * scale + view.panOffset.dy;
        canvas.drawCircle(Offset(sx, sy), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) =>
      oldDelegate.view.panOffset != view.panOffset ||
      oldDelegate.view.scale != view.scale;
}
