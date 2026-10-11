import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../controllers/undo_controller.dart';
import '../geometry/frame_geometry.dart';
import '../geometry/masonry_layout.dart';
import 'pinterest_service.dart';
import 'remote_image_fetch_service.dart';

const _uuid = Uuid();

/// Reported once an import finishes, so the caller can show the user a
/// plain-language summary - mirrors `PurImportSummary`'s role for the
/// existing PureRef-file import.
class PinterestImportResult {
  PinterestImportResult({
    required this.importedCount,
    required this.failedCount,
  });

  final int importedCount;
  final int failedCount;

  bool get isEmpty => importedCount == 0 && failedCount == 0;
}

/// Downloads every pin in [board] at its original resolution, lays them
/// out in a new frame centered on the current viewport, and adds each as
/// an image clip - one combined undo entry covers the whole batch (bin
/// every added clip + remove the frame; redo recreates the frame and
/// restores/re-parents every clip, in that order - see the inline undo/
/// redo comment below for why this exact order, not `deleteFrame` alone,
/// is required for a correct round-trip).
///
/// [onProgress] is called after each pin finishes downloading (success or
/// failure) with `(completed, total)`, so the caller can show a progress
/// indicator - a board can have hundreds of pins, and each is a separate
/// network request.
Future<PinterestImportResult> importPinterestBoard(
  WidgetRef ref, {
  required PinterestBoard board,
  required BuildContext context,
  void Function(int completed, int total)? onProgress,
}) async {
  // Captured up front, before any `await` - the dialog that owns [context]
  // is guaranteed mounted at the moment its own "Import" button handler
  // calls this function synchronously, but downloading every pin can take
  // many seconds, during which the dialog could be dismissed. This also
  // means the new frame centers on wherever the user was looking when they
  // clicked Import, not wherever the viewport happened to drift to after a
  // long download - the more correct behavior either way.
  final screenSize = MediaQuery.sizeOf(context);
  final pinterest = PinterestService();
  final List<PinterestPinImage> pins;
  try {
    pins = await pinterest.fetchBoardPins(board.id);
  } finally {
    pinterest.close();
  }
  if (pins.isEmpty) {
    return PinterestImportResult(importedCount: 0, failedCount: 0);
  }

  // Download every pin's image bytes first (so a failed layout/DB write
  // doesn't leave a half-downloaded mess), tracking which succeeded by
  // index so failures just drop out of the aspect-ratio list below
  // instead of leaving a gap.
  final downloaded = <int, ({Uint8List bytes, String extension})>{};
  var completed = 0;
  for (var i = 0; i < pins.length; i++) {
    final fetched = await fetchImageBytes(Uri.parse(pins[i].url));
    if (fetched != null) {
      downloaded[i] = (bytes: fetched.bytes, extension: fetched.extension);
    }
    completed++;
    onProgress?.call(completed, pins.length);
  }
  final succeededIndices = downloaded.keys.toList()..sort();
  final failedCount = pins.length - succeededIndices.length;
  if (succeededIndices.isEmpty) {
    return PinterestImportResult(importedCount: 0, failedCount: failedCount);
  }

  // Heuristic target size for the packed layout: assume a roughly square
  // average cell at containerWidth/4 (i.e. ~4 columns), scaled by item
  // count, then let MasonryLayout.pack solve the real per-item sizes -
  // this only tunes how tall the initial frame looks, not correctness;
  // the user can always resize/rearrange afterward like any other frame.
  const containerWidth = 1000.0;
  final targetTotalHeight = math.max(
    containerWidth / 2,
    succeededIndices.length * containerWidth / 16,
  );
  final aspectRatios = [
    for (final i in succeededIndices) pins[i].width / pins[i].height,
  ];
  final rects = MasonryLayout.pack(
    aspectRatios: aspectRatios,
    containerWidth: containerWidth,
    targetTotalHeight: targetTotalHeight,
    gap: 8,
  );
  final frameWidth = rects.isEmpty
      ? containerWidth
      : rects.map((r) => r.right).reduce(math.max);
  final frameHeight = rects.isEmpty
      ? targetTotalHeight
      : rects.map((r) => r.bottom).reduce(math.max);

  final view = ref.read(boardViewProvider);
  final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
  final boardCenter = (screenCenter - view.panOffset) / view.scale;
  final frameX = boardCenter.dx - frameWidth / 2;
  final frameY = boardCenter.dy - frameHeight / 2;

  final boardId = ref.read(currentBoardIdProvider);
  final framesRepo = ref.read(framesRepositoryProvider);
  final clipsRepo = ref.read(clipsRepositoryProvider);
  final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
  final frameId = _uuid.v4();
  final frameName = board.name.trim().isEmpty
      ? FrameGeometry.nextAvailableFrameName(frames)
      : board.name.trim();

  await framesRepo.createFrame(
    id: frameId,
    boardId: boardId,
    name: frameName,
    x: frameX,
    y: frameY,
    width: frameWidth,
    height: frameHeight,
  );

  final clipIds = <String>[];
  for (var j = 0; j < succeededIndices.length; j++) {
    final pinIndex = succeededIndices[j];
    final file = downloaded[pinIndex]!;
    final rect = rects[j];
    final id = _uuid.v4();
    final destPath = await ref
        .read(localBlobStoreProvider)
        .writeBytes(file.bytes, extension: file.extension);
    await clipsRepo.addImageClip(
      id: id,
      boardId: boardId,
      localFilePath: destPath,
      x: frameX + rect.left,
      y: frameY + rect.top,
      width: rect.width,
      height: rect.height,
      imageAspectRatio: pins[pinIndex].width / pins[pinIndex].height,
    );
    await clipsRepo.setFrameId(id, frameId);
    clipIds.add(id);
  }

  // `FramesRepository.deleteFrame` unparents children unconditionally
  // (clears frameId on every clip currently pointing at this frame,
  // regardless of bin state - confirmed by reading its implementation)
  // before deleting the frame row. So undo must call deleteFrame FIRST
  // (while every clip is still active, so the unparenting - harmless,
  // they're about to be binned anyway - completes cleanly), THEN bin the
  // clips; redo must recreate the frame, restore each clip, and only
  // then re-set each one's frameId (restoreClip doesn't touch frameId,
  // and it was already cleared by deleteFrame's own cascade). Doing this
  // in the opposite order would silently lose each clip's frame
  // membership on a redo after an undo.
  ref
      .read(undoManagerProvider.notifier)
      .push(
        UndoableAction(
          undo: () async {
            await framesRepo.deleteFrame(frameId);
            await Future.wait(clipIds.map(clipsRepo.binClip));
          },
          redo: () async {
            await framesRepo.createFrame(
              id: frameId,
              boardId: boardId,
              name: frameName,
              x: frameX,
              y: frameY,
              width: frameWidth,
              height: frameHeight,
            );
            await Future.wait(clipIds.map(clipsRepo.restoreClip));
            await Future.wait(
              clipIds.map((id) => clipsRepo.setFrameId(id, frameId)),
            );
          },
        ),
      );

  return PinterestImportResult(
    importedCount: clipIds.length,
    failedCount: failedCount,
  );
}
