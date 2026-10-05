import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart' show FrameRow;
import '../../../data/providers.dart';
import '../controllers/undo_controller.dart';
import '../geometry/frame_geometry.dart';
import '../geometry/frame_presets.dart';

/// Resizes [frame] to exactly [preset]'s width/height, scaling every
/// child clip proportionally via `FrameGeometry.scaleChildren` (anchored
/// at the frame's own top-left corner, the same math a manual frame
/// resize already uses) and pushing one combined undo/redo action
/// covering the frame and every scaled child. Shared by the toolbar's
/// "Frame size preset" dialog (`board_screen.dart`) and
/// `FrameOptionsMenu`'s inline aspect-ratio dropdown - both apply a
/// preset through this exact same logic, so there is one source of
/// truth for "what happens when you pick a preset."
Future<void> applyFramePreset(
  WidgetRef ref,
  FrameRow frame,
  FramePreset preset,
) async {
  final startRect = FrameGeometry.boardRect(frame);
  final newRect = Rect.fromLTWH(
    startRect.left,
    startRect.top,
    preset.width,
    preset.height,
  );
  final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
  final children = {
    for (final c in clips)
      if (c.frameId == frame.id) c.id: c,
  };
  final scaled = FrameGeometry.scaleChildren(
    startClips: children,
    startRect: startRect,
    newRect: newRect,
  );

  final framesRepo = ref.read(framesRepositoryProvider);
  final clipsRepo = ref.read(clipsRepositoryProvider);
  await framesRepo.updateTransform(
    frame.id,
    width: preset.width,
    height: preset.height,
  );
  for (final entry in scaled.entries) {
    await clipsRepo.updateTransform(
      entry.key,
      x: entry.value.x,
      y: entry.value.y,
      width: entry.value.width,
      height: entry.value.height,
    );
  }
  ref
      .read(undoManagerProvider.notifier)
      .push(
        UndoableAction(
          undo: () => Future.wait([
            framesRepo.updateTransform(
              frame.id,
              width: startRect.width,
              height: startRect.height,
            ),
            for (final entry in children.entries)
              clipsRepo.updateTransform(
                entry.key,
                x: entry.value.x,
                y: entry.value.y,
                width: entry.value.width,
                height: entry.value.height,
              ),
          ]),
          redo: () => Future.wait([
            framesRepo.updateTransform(
              frame.id,
              width: preset.width,
              height: preset.height,
            ),
            for (final entry in scaled.entries)
              clipsRepo.updateTransform(
                entry.key,
                x: entry.value.x,
                y: entry.value.y,
                width: entry.value.width,
                height: entry.value.height,
              ),
          ]),
        ),
      );
}
