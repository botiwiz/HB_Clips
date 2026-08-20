import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../geometry/selection_geometry.dart';

/// Draws the resize/rotate handles for the sole selected clip. Purely
/// presentational - all pointer handling/hit-testing for these handles
/// happens in `board_canvas.dart`'s Listener, per the board's
/// no-gesture-arena architecture. Renders nothing unless exactly one clip
/// is selected (group resize/rotate is out of scope for Phase 2).
class SelectionHandles extends ConsumerWidget {
  const SelectionHandles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedClipIdsProvider);
    if (selection.length != 1) return const SizedBox.shrink();
    final id = selection.first;

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    var clip = ClipGeometry.findById(clips, id);
    if (clip == null) return const SizedBox.shrink();

    final dragging = ref.watch(groupDragProvider)?[id];
    if (dragging != null) {
      clip = clip.copyWith(
        x: dragging.x,
        y: dragging.y,
        width: dragging.width,
        height: dragging.height,
        rotation: dragging.rotation,
      );
    }

    final view = ref.watch(boardViewProvider);
    final positions = ClipGeometry.handleScreenPositions(clip, view);

    return Stack(
      children: [
        for (final entry in positions.entries)
          _handle(entry.key, entry.value),
      ],
    );
  }

  Widget _handle(HandleKind kind, Offset screenPosition) {
    final size = kind == HandleKind.rotate
        ? ClipGeometry.handleVisualSize + 4
        : ClipGeometry.handleVisualSize;
    return Positioned(
      left: screenPosition.dx - size / 2,
      top: screenPosition.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kind == HandleKind.rotate ? AppTheme.accent : Colors.white,
            shape: kind == HandleKind.rotate
                ? BoxShape.circle
                : BoxShape.rectangle,
            border: Border.all(color: Colors.black87, width: 1),
          ),
        ),
      ),
    );
  }
}
