import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/board_controller.dart';

/// Draws the rectangle while a text-tool click-drag is in progress - see
/// `board_canvas.dart`'s `_handleTextToolPointerMove`. Structurally
/// identical to `DefineFrameOverlay`/`MarqueeOverlay`.
class TextToolDragOverlay extends ConsumerWidget {
  const TextToolDragOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardRect = ref.watch(textToolDragRectProvider);
    if (boardRect == null) return const SizedBox.shrink();
    final view = ref.watch(boardViewProvider);

    final topLeft = boardRect.topLeft * view.scale + view.panOffset;
    final size = boardRect.size * view.scale;

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15),
            border: Border.all(color: AppTheme.accent, width: 1),
          ),
        ),
      ),
    );
  }
}
