import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/clips_repository.dart';
import '../services/gif_controller_service.dart';

const _uuid = Uuid();

/// Floating pill shown while a single GIF clip is selected: play/pause, a
/// frame-step slider, a speed control, and "extract this frame" - PureRef's
/// GIF playback controls, layered on top of Flutter's already-free
/// `Image.file` autoplay/loop.
class GifPlaybackToolbar extends ConsumerWidget {
  final BoardClip clip;

  const GifPlaybackToolbar({super.key, required this.clip});

  Future<void> _extractFrame(BuildContext context, WidgetRef ref) async {
    final state = ref.read(gifPlaybackControllerProvider);
    if (state == null || state.clipId != clip.id) return;
    final frame = state.frames[state.currentFrame];
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) return;

    final id = _uuid.v4();
    final supportDir = await getApplicationSupportDirectory();
    final clipsDir = Directory(p.join(supportDir.path, 'clips'));
    await clipsDir.create(recursive: true);
    final destPath = p.join(clipsDir.path, '$id.png');
    await File(destPath).writeAsBytes(byteData.buffer.asUint8List());

    try {
      await ref
          .read(clipsRepositoryProvider)
          .addImageClip(
            id: id,
            boardId: ref.read(currentBoardIdProvider),
            localFilePath: destPath,
            x: clip.x + 24,
            y: clip.y + 24,
            width: clip.width,
            height: clip.height,
          );
    } on ClipCapExceededException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You've reached the 30 image clip limit. Bin or delete one to "
            'extract a frame.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gifPlaybackControllerProvider);
    final isThisClip = state?.clipId == clip.id;
    final frameCount = isThisClip ? state!.frames.length : 0;
    final currentFrame = isThisClip ? state!.currentFrame : 0;
    final playing = isThisClip && state!.playing;
    final speed = isThisClip ? state!.speed : 1.0;
    final canScrub = isThisClip && frameCount > 1;

    return Material(
      color: AppTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(999),
      elevation: 6,
      shadowColor: Colors.black54,
      child: Container(
        height: 48,
        width: 440,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            IconButton(
              tooltip: playing ? 'Pause' : 'Play',
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: isThisClip
                  ? () => ref
                        .read(gifPlaybackControllerProvider.notifier)
                        .togglePlay()
                  : null,
            ),
            Expanded(
              child: Slider(
                value: canScrub ? currentFrame.toDouble() : 0,
                min: 0,
                max: canScrub ? (frameCount - 1).toDouble() : 1,
                divisions: canScrub ? frameCount - 1 : null,
                onChanged: canScrub
                    ? (value) => ref
                          .read(gifPlaybackControllerProvider.notifier)
                          .seekToFrame(value.round())
                    : null,
              ),
            ),
            DropdownButton<double>(
              value: speed,
              underline: const SizedBox.shrink(),
              items: const [0.25, 0.5, 1.0, 2.0, 4.0]
                  .map(
                    (s) => DropdownMenuItem(value: s, child: Text('${s}x')),
                  )
                  .toList(),
              onChanged: isThisClip
                  ? (value) {
                      if (value != null) {
                        ref
                            .read(gifPlaybackControllerProvider.notifier)
                            .setSpeed(value);
                      }
                    }
                  : null,
            ),
            IconButton(
              tooltip: 'Extract this frame as a new clip',
              icon: const Icon(Icons.image_outlined),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: isThisClip
                  ? () => _extractFrame(context, ref)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
