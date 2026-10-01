import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/board_controller.dart';
import 'shape_painter.dart';

/// Draws the live placement preview while a shape-tool click-drag is in
/// progress - see `board_canvas.dart`'s `_handleShapeToolPointerMove`.
/// Structurally identical to `TextToolDragOverlay`, but renders the actual
/// target shape's outline (via the same `ShapePainter` used for the real
/// clip) instead of a generic translucent rect.
class ShapeToolDragOverlay extends ConsumerWidget {
  const ShapeToolDragOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardRect = ref.watch(shapeToolDragRectProvider);
    if (boardRect == null) return const SizedBox.shrink();
    final view = ref.watch(boardViewProvider);
    final kind = ref.watch(selectedShapeKindProvider);

    final topLeft = boardRect.topLeft * view.scale + view.panOffset;
    final size = boardRect.size * view.scale;

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: CustomPaint(
          painter: ShapePainter(
            kind: kind,
            fillColor: AppTheme.accent.withValues(alpha: 0.15),
            strokeColor: AppTheme.accent,
            strokeWidth: 1,
          ),
        ),
      ),
    );
  }
}
