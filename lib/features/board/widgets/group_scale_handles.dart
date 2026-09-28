import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../geometry/selection_geometry.dart';

/// Draws resize handles at the 4 corners of a multi-selection's bounding
/// box, for scaling the whole group together (size and position,
/// proportionally). Purely presentational - all gesture handling lives in
/// `board_canvas.dart`'s Listener, mirroring `SelectionHandles`. Renders
/// nothing unless at least 2 clips are selected and every one of them
/// currently has rotation == 0 (v1 restriction: rotated-group scaling
/// needs each clip's corners scaled around the group anchor, which is
/// meaningfully more math for a first pass - see `ClipGeometry.scaleGroup`).
class GroupScaleHandles extends ConsumerWidget {
  const GroupScaleHandles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedClipIdsProvider);
    if (selection.length < 2) return const SizedBox.shrink();

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final selected = [
      for (final c in clips)
        if (selection.contains(c.id)) c,
    ];
    if (selected.length < 2) return const SizedBox.shrink();
    if (selected.any((c) => c.rotation != 0)) return const SizedBox.shrink();

    final dragging = ref.watch(groupDragProvider);
    final effective = [
      for (final c in selected)
        if (dragging?[c.id] case final d?)
          c.copyWith(x: d.x, y: d.y, width: d.width, height: d.height)
        else
          c,
    ];

    final view = ref.watch(boardViewProvider);
    final rect = ClipGeometry.boardBoundingBox(effective);
    final positions = ClipGeometry.rectHandleScreenPositions(rect, view);

    return Stack(
      children: [
        for (final entry in positions.entries) _handle(entry.value),
      ],
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
