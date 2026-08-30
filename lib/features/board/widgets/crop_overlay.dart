import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../controllers/crop_controller.dart';
import '../geometry/crop_geometry.dart';
import '../geometry/selection_geometry.dart';

/// Purely presentational, like `SelectionHandles` - all pointer handling for
/// the crop rect's handles happens in `board_canvas.dart`'s Listener. Draws
/// the crop rect's rotated outline (a `Transform.rotate`d box, since the
/// rect rigidly rotates with its clip) plus its 8 handles.
class CropOverlay extends ConsumerWidget {
  const CropOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isCropModeProvider)) return const SizedBox.shrink();

    final selection = ref.watch(selectedClipIdsProvider);
    if (selection.length != 1) return const SizedBox.shrink();

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final clip = ClipGeometry.findById(clips, selection.first);
    if (clip == null) return const SizedBox.shrink();

    final cropRect = ref.watch(cropRectProvider) ?? const Rect.fromLTWH(0, 0, 1, 1);
    final view = ref.watch(boardViewProvider);

    final center = ClipGeometry.clipCenter(clip);
    final localCenter = Offset(
      clip.x + (cropRect.left + cropRect.right) / 2 * clip.width,
      clip.y + (cropRect.top + cropRect.bottom) / 2 * clip.height,
    );
    final rotatedCenter = ClipGeometry.rotatePoint(
      localCenter,
      center,
      clip.rotation,
    );
    final screenCenter = Offset(
      rotatedCenter.dx * view.scale + view.panOffset.dx,
      rotatedCenter.dy * view.scale + view.panOffset.dy,
    );
    final screenWidth = cropRect.width * clip.width * view.scale;
    final screenHeight = cropRect.height * clip.height * view.scale;

    final handles = CropGeometry.handleScreenPositions(clip, view, cropRect);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: screenCenter.dx - screenWidth / 2,
            top: screenCenter.dy - screenHeight / 2,
            width: screenWidth,
            height: screenHeight,
            child: Transform.rotate(
              angle: clip.rotation,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.red, width: 2),
                ),
              ),
            ),
          ),
          for (final entry in handles.entries)
            Positioned(
              left: entry.value.dx - 5,
              top: entry.value.dy - 5,
              width: 10,
              height: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.canvasBackground),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
