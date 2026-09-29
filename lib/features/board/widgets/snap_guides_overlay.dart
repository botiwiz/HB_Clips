import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/board_controller.dart';

/// Miro-style "smart guide" line(s) shown while a clip-group drag has an
/// edge snapped into alignment with a nearby clip's or frame's edge - see
/// `SnapGeometry`. Purely presentational, like `MarqueeOverlay`/
/// `DefineFrameOverlay`; `board_canvas.dart` computes the alignment itself
/// and only reports where (if anywhere) a line should show.
class SnapGuidesOverlay extends ConsumerWidget {
  const SnapGuidesOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guides = ref.watch(snapGuidesProvider);
    if (guides.x == null && guides.y == null) return const SizedBox.shrink();
    final view = ref.watch(boardViewProvider);

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _SnapGuidesPainter(guides, view)),
      ),
    );
  }
}

class _SnapGuidesPainter extends CustomPainter {
  final ({double? x, double? y}) guides;
  final BoardViewState view;

  _SnapGuidesPainter(this.guides, this.view);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    final x = guides.x;
    if (x != null) {
      final screenX = x * view.scale + view.panOffset.dx;
      canvas.drawLine(Offset(screenX, 0), Offset(screenX, size.height), paint);
    }
    final y = guides.y;
    if (y != null) {
      final screenY = y * view.scale + view.panOffset.dy;
      canvas.drawLine(Offset(0, screenY), Offset(size.width, screenY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnapGuidesPainter oldDelegate) =>
      oldDelegate.guides != guides || oldDelegate.view != view;
}
