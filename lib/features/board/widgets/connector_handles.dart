import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../geometry/connector_geometry.dart';
import '../geometry/selection_geometry.dart';

/// Draws the 4 edge-midpoint dots a selected text clip's edges get,
/// draggable in `board_canvas.dart`'s Listener to start a connector to an
/// image clip elsewhere on the board. Purely presentational, same
/// architecture as `SelectionHandles`. Renders nothing unless exactly one
/// clip is selected and it's a text clip.
class ConnectorHandles extends ConsumerWidget {
  const ConnectorHandles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedClipIdsProvider);
    if (selection.length != 1) return const SizedBox.shrink();
    final id = selection.first;

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    var clip = ClipGeometry.findById(clips, id);
    if (clip == null || clip.type != ClipType.text) {
      return const SizedBox.shrink();
    }

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
    final positions = ConnectorGeometry.handleScreenPositions(clip, view);

    return Stack(
      children: [for (final entry in positions.entries) _handle(entry.value)],
    );
  }

  Widget _handle(Offset screenPosition) {
    const size = ConnectorGeometry.handleVisualSize;
    return Positioned(
      left: screenPosition.dx - size / 2,
      top: screenPosition.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.textSecondary,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.canvasBackground, width: 1),
          ),
        ),
      ),
    );
  }
}
