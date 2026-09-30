import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../geometry/masonry_layout.dart';
import '../geometry/selection_geometry.dart';

/// A small circular handle at the top-right corner of a multi-selection's
/// bounding box (Miro's "Arrange" affordance) - purely presentational, like
/// `SelectionHandles`/`GroupScaleHandles`. All gesture handling (including
/// drag-to-arrange, live-previewing a repack at whatever size you drag to)
/// happens in `board_canvas.dart`'s Listener, same architecture as every
/// other draggable handle on this board. A plain click with no movement
/// reproduces the original one-shot behavior: repacks every selected
/// *image* clip into variable-width columns that together exactly fill the
/// selection's current bounding box - no gaps, no ragged bottom edge, no
/// distortion, and no single sparse image forced to stretch across the
/// whole width alone - see `MasonryLayout`. Text notes in the same
/// selection are left untouched (resizing a note's box doesn't rescale its
/// font, so shrinking it could clip text or leave dead space).
class ArrangeSelectionButton extends ConsumerWidget {
  const ArrangeSelectionButton({super.key});

  static const double size = 32;
  static const double _gapAboveCorner = 12;

  /// Screen-space bounds of the button for the given selection bounding box
  /// (board-space) at the current [view] - used both to lay out the widget
  /// itself and by `BoardCanvas` to know when a pointer-down should start
  /// an arrange-drag instead of being treated as an empty-canvas click or
  /// clip/marquee interaction.
  static Rect screenRectFor(Rect selectionBoardRect, BoardViewState view) {
    final topRightBoard = Offset(
      selectionBoardRect.right,
      selectionBoardRect.top,
    );
    final topRightScreen = topRightBoard * view.scale + view.panOffset;
    final left = topRightScreen.dx - size / 2;
    final top = topRightScreen.dy - size - _gapAboveCorner;
    return Rect.fromLTWH(left, top < 8 ? 8 : top, size, size);
  }

  /// Sorts [selected]'s image clips (top-to-bottom, then left-to-right) and
  /// packs them into [targetRect] via [MasonryLayout]. Returns null if
  /// fewer than 2 images are in the selection - nothing to arrange. A pure
  /// function so live preview (every pointer-move) and the final commit
  /// (pointer-up) are guaranteed to agree - there is exactly one packing
  /// code path, not two that could drift apart.
  static Map<String, ({double x, double y, double width, double height})>?
  packImages(List<BoardClip> selected, Rect targetRect) {
    final images = [
      for (final c in selected)
        if (c.type == ClipType.image) c,
    ]..sort((a, b) {
      final byY = a.y.compareTo(b.y);
      return byY != 0 ? byY : a.x.compareTo(b.x);
    });
    if (images.length < 2) return null;

    final rects = MasonryLayout.pack(
      aspectRatios: [for (final c in images) c.width / c.height],
      containerWidth: targetRect.width,
      targetTotalHeight: targetRect.height,
      gap: 2,
    );

    return {
      for (var i = 0; i < images.length; i++)
        images[i].id: (
          x: rects[i].left + targetRect.left,
          y: rects[i].top + targetRect.top,
          width: rects[i].width,
          height: rects[i].height,
        ),
    };
  }

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

    final view = ref.watch(boardViewProvider);
    final liveRect = ref.watch(arrangeDragRectProvider);
    final boardRect = liveRect ?? ClipGeometry.boardBoundingBox(selected);
    final rect = screenRectFor(boardRect, view);

    return Positioned(
      left: rect.left,
      top: rect.top,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: IgnorePointer(
          child: Material(
            color: AppTheme.surfaceElevated,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: Colors.black54,
            child: const SizedBox(
              width: size,
              height: size,
              child: Center(
                child: Icon(
                  Icons.grid_view_rounded,
                  size: 20,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
