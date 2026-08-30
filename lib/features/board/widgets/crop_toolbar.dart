import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../controllers/crop_controller.dart';
import '../geometry/selection_geometry.dart';
import '../services/image_crop_service.dart';

const _uuid = Uuid();

/// Floating pill toolbar shown while the crop tool is active: just confirm
/// and cancel - the crop rectangle itself is dragged directly on the canvas
/// via `CropOverlay`'s handles.
class CropToolbar extends ConsumerWidget {
  const CropToolbar({super.key});

  Future<void> _confirm(WidgetRef ref) async {
    final selection = ref.read(selectedClipIdsProvider);
    if (selection.length != 1) return;
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final clip = ClipGeometry.findById(clips, selection.first);
    if (clip == null || clip.localFilePath == null) return;

    final cropRect = ref.read(cropRectProvider) ?? const Rect.fromLTWH(0, 0, 1, 1);
    // A crop that's a no-op (still the full rect) needs no file work.
    if (cropRect == const Rect.fromLTWH(0, 0, 1, 1)) {
      ref.read(isCropModeProvider.notifier).state = false;
      ref.read(cropRectProvider.notifier).state = null;
      return;
    }

    final result = await cropImageFile(clip.localFilePath!, cropRect);
    if (result == null) return;

    final supportDir = await getApplicationSupportDirectory();
    final clipsDir = Directory(p.join(supportDir.path, 'clips'));
    await clipsDir.create(recursive: true);
    final newPath = p.join(clipsDir.path, '${_uuid.v4()}.png');
    await File(newPath).writeAsBytes(result.pngBytes);

    final oldPath = clip.localFilePath!;
    await ref
        .read(clipsRepositoryProvider)
        .replaceImage(
          clip.id,
          localFilePath: newPath,
          x: clip.x + cropRect.left * clip.width,
          y: clip.y + cropRect.top * clip.height,
          width: cropRect.width * clip.width,
          height: cropRect.height * clip.height,
        );

    try {
      await File(oldPath).delete();
    } catch (_) {
      // Best-effort cleanup; a leftover file here is harmless.
    }

    ref.read(isCropModeProvider.notifier).state = false;
    ref.read(cropRectProvider.notifier).state = null;
  }

  void _cancel(WidgetRef ref) {
    ref.read(isCropModeProvider.notifier).state = false;
    ref.read(cropRectProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(999),
      elevation: 6,
      shadowColor: Colors.black54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('Crop', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            IconButton(
              tooltip: 'Cancel crop',
              icon: const Icon(Icons.close),
              onPressed: () => _cancel(ref),
            ),
            IconButton(
              tooltip: 'Confirm crop',
              icon: const Icon(Icons.check, color: AppTheme.red),
              onPressed: () => _confirm(ref),
            ),
          ],
        ),
      ),
    );
  }
}
