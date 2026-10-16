import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/board_controller.dart';
import '../geometry/spacing_snap_geometry.dart';

/// Miro-style "smart guide" line(s) shown while a clip-group drag has an
/// edge snapped into alignment with a nearby clip's or frame's edge (see
/// `SnapGeometry`), plus equal-spacing/distribution brackets and a numeric
/// label when a spacing-snap match is active instead (see
/// `SpacingSnapGeometry`). Purely presentational, like `MarqueeOverlay`/
/// `DefineFrameOverlay`; `board_canvas.dart` computes the alignment itself
/// and only reports where (if anywhere) a guide should show.
class SnapGuidesOverlay extends ConsumerWidget {
  const SnapGuidesOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guides = ref.watch(snapGuidesProvider);
    final spacing = ref.watch(spacingSnapGuidesProvider);
    if (guides.x == null &&
        guides.y == null &&
        spacing.x == null &&
        spacing.y == null) {
      return const SizedBox.shrink();
    }
    final view = ref.watch(boardViewProvider);

    Offset toScreen(Offset boardPoint) =>
        boardPoint * view.scale + view.panOffset;

    Widget label(SpacingGuide g) {
      final center = toScreen(g.gapRects[0].center);
      return Positioned(
        left: center.dx,
        top: center.dy,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(kCornerRadius),
              border: Border.all(color: AppTheme.border, width: 1),
            ),
            child: Text(
              '${g.distance.round()}',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SnapGuidesPainter(guides, spacing, view),
            ),
          ),
          if (spacing.x != null) label(spacing.x!),
          if (spacing.y != null) label(spacing.y!),
        ],
      ),
    );
  }
}

class _SnapGuidesPainter extends CustomPainter {
  final ({double? x, double? y}) edgeGuides;
  final ({SpacingGuide? x, SpacingGuide? y}) spacingGuides;
  final BoardViewState view;

  _SnapGuidesPainter(this.edgeGuides, this.spacingGuides, this.view);

  Rect _toScreenRect(Rect r) => Rect.fromPoints(
    r.topLeft * view.scale + view.panOffset,
    r.bottomRight * view.scale + view.panOffset,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    final x = edgeGuides.x;
    if (x != null) {
      final screenX = x * view.scale + view.panOffset.dx;
      canvas.drawLine(
        Offset(screenX, 0),
        Offset(screenX, size.height),
        edgePaint,
      );
    }
    final y = edgeGuides.y;
    if (y != null) {
      final screenY = y * view.scale + view.panOffset.dy;
      canvas.drawLine(
        Offset(0, screenY),
        Offset(size.width, screenY),
        edgePaint,
      );
    }

    final spacingPaint = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    const tickHalf = 4.0;

    void drawGap(SpacingGuide guide) {
      for (final boardRect in guide.gapRects) {
        final r = _toScreenRect(boardRect);
        if (guide.axis == Axis.horizontal) {
          final midY = r.center.dy;
          canvas.drawLine(
            Offset(r.left, midY),
            Offset(r.right, midY),
            spacingPaint,
          );
          canvas.drawLine(
            Offset(r.left, midY - tickHalf),
            Offset(r.left, midY + tickHalf),
            spacingPaint,
          );
          canvas.drawLine(
            Offset(r.right, midY - tickHalf),
            Offset(r.right, midY + tickHalf),
            spacingPaint,
          );
        } else {
          final midX = r.center.dx;
          canvas.drawLine(
            Offset(midX, r.top),
            Offset(midX, r.bottom),
            spacingPaint,
          );
          canvas.drawLine(
            Offset(midX - tickHalf, r.top),
            Offset(midX + tickHalf, r.top),
            spacingPaint,
          );
          canvas.drawLine(
            Offset(midX - tickHalf, r.bottom),
            Offset(midX + tickHalf, r.bottom),
            spacingPaint,
          );
        }
      }
    }

    if (spacingGuides.x != null) drawGap(spacingGuides.x!);
    if (spacingGuides.y != null) drawGap(spacingGuides.y!);
  }

  @override
  bool shouldRepaint(covariant _SnapGuidesPainter oldDelegate) =>
      oldDelegate.edgeGuides != edgeGuides ||
      oldDelegate.spacingGuides != spacingGuides ||
      oldDelegate.view != view;
}
