import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart' show FrameRow;
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../geometry/frame_presets.dart';
import '../services/apply_frame_preset.dart';

/// Small "..." trigger shown immediately to the right of a selected
/// frame's name label, opening a grouped dropdown of aspect-ratio/size
/// presets (square, mobile, tablet, screen resolutions, ultrawide,
/// common monitor ratios, paper - see `kFrameAspectRatioGroups`), each
/// applied via the exact same [applyFramePreset] logic the toolbar's own
/// "Frame size preset" dialog uses. Only shown while exactly one frame
/// is selected (mirrors rename/color/the old preset dialog's own
/// single-frame-only scope) and not while that frame's title is
/// actively being renamed (`FrameRenameOverlay` occupies the same
/// visual area with its own `TextField`).
class FrameOptionsMenu extends ConsumerWidget {
  const FrameOptionsMenu({super.key});

  static const double buttonSize = 18;

  static const TextStyle _nameStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  /// Screen-space bounds of the trigger button for [frame] at the
  /// current [view] - used both to position the button itself and as a
  /// click-through guard in `board_canvas.dart`'s `_handlePointerDown`
  /// (a tap on this button must not also fall through to the canvas's
  /// own frame-selection/drag logic, same role every other
  /// per-selection floating control in this app already plays).
  /// Anchored right after the frame's own name label
  /// (`FrameWidget`'s `Positioned(left: 0, top: -22)` text, same
  /// `TextStyle`), measured via a [TextPainter] so the button never
  /// overlaps a long name.
  static Rect screenRectFor(FrameRow frame, BoardViewState view) {
    final topLeft = Offset(frame.x, frame.y) * view.scale + view.panOffset;
    final painter = TextPainter(
      text: TextSpan(text: frame.name, style: _nameStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final left = topLeft.dx + painter.width + 6;
    final top = topLeft.dy - 22 + (painter.height - buttonSize) / 2;
    return Rect.fromLTWH(left, top, buttonSize, buttonSize);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFrameIds = ref.watch(selectedFrameIdsProvider);
    if (selectedFrameIds.length != 1) return const SizedBox.shrink();
    // The title-rename overlay occupies the same visual area with its
    // own TextField - don't also show the trigger button on top of it.
    if (ref.watch(renamingFrameIdProvider) != null) {
      return const SizedBox.shrink();
    }

    final frames = ref.watch(boardFramesProvider).valueOrNull ?? [];
    FrameRow? frame;
    for (final f in frames) {
      if (f.id == selectedFrameIds.first) {
        frame = f;
        break;
      }
    }
    if (frame == null) return const SizedBox.shrink();

    final view = ref.watch(boardViewProvider);
    final rect = FrameOptionsMenu.screenRectFor(frame, view);

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: _FrameOptionsButton(frame: frame),
    );
  }
}

class _FrameOptionsButton extends ConsumerWidget {
  final FrameRow frame;

  const _FrameOptionsButton({required this.frame});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      type: MaterialType.transparency,
      child: PopupMenuButton<FramePreset>(
        tooltip: 'Frame options',
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
          for (final group in kFrameAspectRatioGroups) ...[
            PopupMenuItem<FramePreset>(
              enabled: false,
              height: 28,
              child: Text(
                group.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final preset in group.presets)
              PopupMenuItem<FramePreset>(
                value: preset,
                child: Text(preset.label),
              ),
          ],
        ],
        onSelected: (preset) => applyFramePreset(ref, frame, preset),
        child: Container(
          width: FrameOptionsMenu.buttonSize,
          height: FrameOptionsMenu.buttonSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppTheme.surfaceElevated,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.more_horiz,
            size: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
