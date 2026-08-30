import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/color_swatch_button.dart';
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../../annotation/controllers/annotation_controller.dart';
import '../../annotation/stroke_painter.dart';
import '../controllers/board_controller.dart';
import '../geometry/selection_geometry.dart';

/// A small floating pill, positioned above the sole selected clip: an
/// opacity slider always, plus (for text notes only) background-color
/// swatches. Purely presentational, like `SelectionHandles` - every control
/// writes straight through `ClipsRepository`, there's no ephemeral drag
/// state to manage since these are single discrete edits, not gestures.
class ClipStylePopover extends ConsumerWidget {
  const ClipStylePopover({super.key});

  static const double _imagePillHeight = 56;
  static const double _textPillHeight = 100;

  /// Screen-space bounds of the popover for [clip] at the current [view], or
  /// null if it wouldn't be shown - used both to lay out the widget itself
  /// and by `BoardCanvas` to know when a pointer-down should be left alone
  /// (not treated as an empty-canvas click) so taps on the swatches/slider
  /// inside it actually reach them instead of clearing the selection they
  /// depend on.
  static Rect screenRectFor(BoardClip clip, BoardViewState view) {
    final topLeft = Offset(
      clip.x * view.scale + view.panOffset.dx,
      clip.y * view.scale + view.panOffset.dy,
    );
    final boxWidth = clip.width * view.scale;
    final isText = clip.type == ClipType.text;
    final pillWidth = isText ? 220.0 : 180.0;
    final pillHeight = isText ? _textPillHeight : _imagePillHeight;
    final left = topLeft.dx + boxWidth / 2 - pillWidth / 2;
    final top = topLeft.dy - (isText ? 92 : 52);
    return Rect.fromLTWH(left, top < 8 ? 8 : top, pillWidth, pillHeight);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedClipIdsProvider);
    if (selection.length != 1) return const SizedBox.shrink();

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final clip = ClipGeometry.findById(clips, selection.first);
    if (clip == null) return const SizedBox.shrink();

    final view = ref.watch(boardViewProvider);
    final isText = clip.type == ClipType.text;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isText)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ColorSwatchButton(
                      color: AppTheme.textNoteSurface,
                      selected: clip.backgroundColorHex == null,
                      onTap: () => repo.updateBackgroundColor(clip.id, null),
                    ),
                    for (final colorHex in kStrokeColorPalette)
                      ColorSwatchButton(
                        color: hexToColor(colorHex),
                        selected: clip.backgroundColorHex == colorHex,
                        onTap: () =>
                            repo.updateBackgroundColor(clip.id, colorHex),
                      ),
                  ],
                ),
              Row(
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
            ],
          ),
        ),
      ),
    );
  }
}
