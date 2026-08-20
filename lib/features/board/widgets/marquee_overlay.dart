import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/board_controller.dart';

/// Draws the rubber-band selection rectangle while a marquee drag
/// (Shift + left-drag on empty canvas) is in progress. Purely
/// presentational - `board_canvas.dart` owns the drag itself.
class MarqueeOverlay extends ConsumerWidget {
  const MarqueeOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardRect = ref.watch(marqueeRectProvider);
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
