import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/board_controller.dart';

/// Draws the rectangle while a "C"+drag frame redefinition is in progress
/// (see `board_canvas.dart`'s `_defineFrameClip` handling) - structurally
/// identical to `MarqueeOverlay` (a plain axis-aligned rect; a fresh
/// C-drag is never rotated), kept as a separate widget since it's a
/// semantically distinct operation from multi-select.
class DefineFrameOverlay extends ConsumerWidget {
  const DefineFrameOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardRect = ref.watch(defineFrameRectProvider);
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
            color: AppTheme.red.withValues(alpha: 0.15),
            border: Border.all(color: AppTheme.red, width: 1),
          ),
        ),
      ),
    );
  }
}
