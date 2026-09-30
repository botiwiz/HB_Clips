import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../geometry/selection_geometry.dart';

/// A small floating pill, positioned above the sole selected clip: an
/// opacity slider. Image clips only - a text clip's own edit-mode toolbar
/// (`TextClipEditOverlay`) covers formatting/size for notes instead, so
/// this renders nothing for a text clip (no background-color swatches or
/// opacity slider for notes - dropped in favor of that toolbar). Purely
/// presentational, like `SelectionHandles` - every control writes straight
/// through `ClipsRepository`, there's no ephemeral drag state to manage
/// since these are single discrete edits, not gestures.
class ClipStylePopover extends ConsumerWidget {
  const ClipStylePopover({super.key});

  static const double _pillHeight = 56;
  static const double _pillWidth = 180;

  /// Screen-space bounds of the popover for [clip] at the current [view] -
  /// used both to lay out the widget itself and by `BoardCanvas` to know
  /// when a pointer-down should be left alone (not treated as an
  /// empty-canvas click) so taps on the slider inside it actually reach it
  /// instead of clearing the selection it depends on. Callers should only
  /// use this for image clips - see the class doc comment.
  static Rect screenRectFor(BoardClip clip, BoardViewState view) {
    final topLeft = Offset(
      clip.x * view.scale + view.panOffset.dx,
      clip.y * view.scale + view.panOffset.dy,
    );
    final boxWidth = clip.width * view.scale;
    final left = topLeft.dx + boxWidth / 2 - _pillWidth / 2;
    final top = topLeft.dy - 52;
    return Rect.fromLTWH(left, top < 8 ? 8 : top, _pillWidth, _pillHeight);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedClipIdsProvider);
    if (selection.length != 1) return const SizedBox.shrink();

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final clip = ClipGeometry.findById(clips, selection.first);
    if (clip == null || clip.type != ClipType.image) {
      return const SizedBox.shrink();
    }

    final view = ref.watch(boardViewProvider);
    final rect = screenRectFor(clip, view);
    final repo = ref.read(clipsRepositoryProvider);

    return Positioned(
      left: rect.left,
      top: rect.top,
      child: Material(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        elevation: 6,
        shadowColor: Colors.black54,
        child: Container(
          width: rect.width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.opacity,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              Expanded(
                child: Slider(
                  value: clip.opacity,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (value) =>
                      repo.updateTransform(clip.id, opacity: value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
