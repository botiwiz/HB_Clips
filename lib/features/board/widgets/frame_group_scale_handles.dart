import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../geometry/frame_geometry.dart';
import '../geometry/selection_geometry.dart';

/// Draws resize handles at the 4 corners of a 2+-frame selection's
/// bounding box, for scaling the whole group together - the frame
/// equivalent of `GroupScaleHandles`. Purely presentational, all
/// gesture handling lives in `board_canvas.dart`'s Listener. Unlike
/// `GroupScaleHandles`, there's no rotation gate - frames never rotate,
/// so every frame is always eligible once 2+ are selected.
class FrameGroupScaleHandles extends ConsumerWidget {
  const FrameGroupScaleHandles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedFrameIdsProvider);
    if (selection.length < 2) return const SizedBox.shrink();

    final frames = ref.watch(boardFramesProvider).valueOrNull ?? [];
    final selected = [
      for (final f in frames)
        if (selection.contains(f.id)) f,
    ];
    if (selected.length < 2) return const SizedBox.shrink();

    final dragging = ref.watch(frameDragRectsProvider);
    final view = ref.watch(boardViewProvider);

    Rect? rect;
    for (final f in selected) {
      final r = dragging?[f.id] ?? FrameGeometry.boardRect(f);
      rect = rect == null ? r : rect.expandToInclude(r);
    }

    final positions = ClipGeometry.rectHandleScreenPositions(rect!, view);

    return Stack(
      children: [for (final entry in positions.entries) _handle(entry.value)],
    );
  }

  Widget _handle(Offset screenPosition) {
    const size = ClipGeometry.handleVisualSize;
    return Positioned(
      left: screenPosition.dx - size / 2,
      top: screenPosition.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.textPrimary,
            border: Border.all(color: AppTheme.canvasBackground, width: 1),
          ),
        ),
      ),
    );
  }
}
