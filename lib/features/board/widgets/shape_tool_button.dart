import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../annotation/controllers/annotation_controller.dart';
import '../controllers/board_controller.dart';
import 'board_toolbar.dart';
import 'shape_painter.dart';

String _label(ShapeKind kind) => switch (kind) {
  ShapeKind.rectangle => 'Rectangle',
  ShapeKind.ellipse => 'Ellipse',
  ShapeKind.triangle => 'Triangle',
  ShapeKind.trapezoid => 'Trapezoid',
  ShapeKind.parallelogram => 'Parallelogram',
};

/// Sits inside the main toolbar's [PillGroup] alongside the other
/// [PillIconButton]s. Inactive: a small popup menu of the 5 [ShapeKind]
/// thumbnails to pick from. Active (the one-shot shape tool is armed):
/// swaps to a plain "cancel" button, mirroring how the text tool's own
/// toolbar button swaps appearance via `isTextToolActiveProvider`.
class ShapeToolButton extends ConsumerWidget {
  const ShapeToolButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(isShapeToolActiveProvider);
    if (active) {
      return PillIconButton(
        tooltip: 'Cancel shape tool',
        icon: Icons.category_outlined,
        color: AppTheme.red,
        onPressed: () =>
            ref.read(isShapeToolActiveProvider.notifier).state = false,
      );
    }
    return PopupMenuButton<ShapeKind>(
      tooltip: 'Shape tool',
      icon: const Icon(Icons.category_outlined),
      iconSize: 20,
      padding: EdgeInsets.zero,
      splashRadius: 20,
      onSelected: (kind) {
        ref.read(selectedShapeKindProvider.notifier).state = kind;
        ref.read(isShapeToolActiveProvider.notifier).state = true;
        ref.read(selectedClipIdsProvider.notifier).state = {};
        ref.read(isDrawModeProvider.notifier).state = false;
        ref.read(isTextToolActiveProvider.notifier).state = false;
      },
      itemBuilder: (context) => [
        for (final kind in ShapeKind.values)
          PopupMenuItem<ShapeKind>(
            value: kind,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CustomPaint(
                    painter: ShapePainter(
                      kind: kind,
                      fillColor: null,
                      strokeColor: AppTheme.textPrimary,
                      strokeWidth: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(_label(kind)),
              ],
            ),
          ),
      ],
    );
  }
}
