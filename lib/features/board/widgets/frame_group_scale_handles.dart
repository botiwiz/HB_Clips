import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../geometry/frame_geometry.dart';
import '../geometry/selection_geometry.dart';

/// Draws resize handles at the 4 corners of a frame-selection's bounding
/// box, for scaling the whole group together - the frame equivalent of
/// `GroupScaleHandles`. Purely presentational, all gesture handling lives
/// in `board_canvas.dart`'s Listener. Unlike `GroupScaleHandles`, there's
/// no rotation gate - frames never rotate, so every frame is always
/// eligible.
///
/// Shows up for two different selection shapes, both meaning "frame
/// selected together with at least one other thing":
///  - 2+ frames selected, no clips (unchanged since this widget's own
///    introduction - scales every selected frame, and everything nested
///    in one, together).
///  - exactly 1 frame selected AND 1+ clips selected alongside it, which
///    only a marquee drag can produce (a plain click always clears the
///    other selection - see `board_canvas.dart`'s frame/clip hit-test
///    branches). Scales that one frame (and its contents) together with
///    the directly-selected clip(s), same math, extended to cover this
///    shape too.
///
/// A LONE selected frame (exactly 1 frame, 0 clips) deliberately does
/// NOT show these handles - that case keeps its own single corner handle
/// on the frame itself (see `FrameWidget`), which only ever resizes the
/// frame's own rect, never its children's. "The frame alone" vs. "the
/// frame and anything else" is exactly the dividing line Miro draws too:
/// resizing a lone frame is reshaping a region, not asking its contents
/// to follow.
class FrameGroupScaleHandles extends ConsumerWidget {
  const FrameGroupScaleHandles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frameSelection = ref.watch(selectedFrameIdsProvider);
    final clipSelection = ref.watch(selectedClipIdsProvider);
    if (frameSelection.isEmpty ||
        frameSelection.length + clipSelection.length < 2) {
      return const SizedBox.shrink();
    }

    final frames = ref.watch(boardFramesProvider).valueOrNull ?? [];
    final selectedFrames = [
      for (final f in frames)
        if (frameSelection.contains(f.id)) f,
    ];
    if (selectedFrames.isEmpty) return const SizedBox.shrink();

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final selectedClips = [
      for (final c in clips)
        if (clipSelection.contains(c.id)) c,
    ];

    final dragging = ref.watch(frameDragRectsProvider);
    final draggingClips = ref.watch(groupDragProvider);
    final view = ref.watch(boardViewProvider);

    Rect? rect;
    for (final f in selectedFrames) {
      final r = dragging?[f.id] ?? FrameGeometry.boardRect(f);
      rect = rect == null ? r : rect.expandToInclude(r);
    }
    for (final c in selectedClips) {
      final d = draggingClips?[c.id];
      final r = d != null
          ? Rect.fromLTWH(d.x, d.y, d.width, d.height)
          : Rect.fromLTWH(c.x, c.y, c.width, c.height);
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
