import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../geometry/justified_layout.dart';
import '../geometry/selection_geometry.dart';

/// A small floating button at the top-right corner of a multi-selection's
/// bounding box (Miro's "Arrange" affordance) - purely presentational plus
/// a one-shot tap action, like `ClipStylePopover`. Repacks every selected
/// *image* clip into a justified/masonry grid that fills the selection's
/// current bounding-box width, each row's height computed automatically so
/// images fit together with no gaps or letterboxing while keeping their own
/// aspect ratio - see `JustifiedLayout`. Text notes in the same selection
/// are left untouched (resizing a note's box doesn't rescale its font, so
/// shrinking it could clip text or leave dead space).
class ArrangeSelectionButton extends ConsumerWidget {
  const ArrangeSelectionButton({super.key});

  static const double size = 32;
  static const double _gapAboveCorner = 12;

  /// Screen-space bounds of the button for the given selection bounding box
  /// (board-space) at the current [view] - used both to lay out the widget
  /// itself and by `BoardCanvas` to know when a pointer-down should be left
  /// alone (not treated as an empty-canvas click) so a tap on the button
  /// actually reaches it instead of clearing the selection it depends on.
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
    final boardRect = ClipGeometry.boardBoundingBox(selected);
    final rect = screenRectFor(boardRect, view);

    return Positioned(
      left: rect.left,
      top: rect.top,
      child: Material(
        color: AppTheme.surfaceElevated,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: Colors.black54,
        child: IconButton(
          iconSize: 16,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(
            width: size,
            height: size,
          ),
          icon: const Icon(
            Icons.grid_view_rounded,
            color: AppTheme.textPrimary,
          ),
          tooltip: 'Arrange selection',
          onPressed: () => _arrange(ref, selected, boardRect),
        ),
      ),
    );
  }

  void _arrange(WidgetRef ref, List<BoardClip> selected, Rect boardRect) {
    final images = [
      for (final c in selected)
        if (c.type == ClipType.image) c,
    ]..sort((a, b) {
      final byY = a.y.compareTo(b.y);
      return byY != 0 ? byY : a.x.compareTo(b.x);
    });
    if (images.length < 2) return;

    final rects = JustifiedLayout.pack(
      aspectRatios: [for (final c in images) c.width / c.height],
      containerWidth: boardRect.width,
      targetTotalHeight: boardRect.height,
    );

    final repo = ref.read(clipsRepositoryProvider);
    for (var i = 0; i < images.length; i++) {
      final r = rects[i].shift(boardRect.topLeft);
      repo.updateTransform(
        images[i].id,
        x: r.left,
        y: r.top,
        width: r.width,
        height: r.height,
        rotation: 0,
      );
    }
  }
}
