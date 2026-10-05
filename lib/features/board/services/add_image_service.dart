import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../controllers/undo_controller.dart';
import 'image_size_service.dart';

const _uuid = Uuid();

void showBoardSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppTheme.danger : null,
    ),
  );
}

/// Pushes the "undo = bin these clips, redo = restore them" entry every
/// "add one or more clips" flow shares - reuses the app's existing
/// bin/restore soft-delete as the undo/redo mechanism, so each newly-added
/// clip's full data survives an undo/redo round-trip exactly like any
/// other binned-then-restored clip. [pushAddClipUndo] is the single-id
/// case every pre-existing "add" flow (the add-image-clip/add-text-note
/// buttons, clipboard paste, drag-and-drop, the text tool, extracting a
/// GIF frame) already uses; Alt-drag-duplicate and internal copy/paste
/// can duplicate several clips in one gesture, so they push one combined
/// entry via this instead of one entry per clip.
void pushAddClipsUndo(WidgetRef ref, List<String> clipIds) {
  final repo = ref.read(clipsRepositoryProvider);
  ref
      .read(undoManagerProvider.notifier)
      .push(
        UndoableAction(
          undo: () => Future.wait(clipIds.map(repo.binClip)),
          redo: () => Future.wait(clipIds.map(repo.restoreClip)),
        ),
      );
}

void pushAddClipUndo(WidgetRef ref, String clipId) =>
    pushAddClipsUndo(ref, [clipId]);

/// Writes [bytes] to local blob storage and adds an image clip centered at
/// [boardCenter], sized to preserve the image's own aspect ratio. Shared by
/// clipboard paste and drag-and-drop - the only two ways an image's raw
/// bytes (rather than an already-on-disk file the user picked) become a
/// clip.
Future<void> addImageClipFromBytes(
  WidgetRef ref, {
  required Uint8List bytes,
  required String extension,
  required Offset boardCenter,
}) async {
  final id = _uuid.v4();
  final destPath = await ref
      .read(localBlobStoreProvider)
      .writeBytes(bytes, extension: extension);

  final clipSize = clipSizeForImageBytes(bytes);
  await ref
      .read(clipsRepositoryProvider)
      .addImageClip(
        id: id,
        boardId: ref.read(currentBoardIdProvider),
        localFilePath: destPath,
        x: boardCenter.dx - clipSize.width / 2,
        y: boardCenter.dy - clipSize.height / 2,
        width: clipSize.width,
        height: clipSize.height,
        imageAspectRatio: imageAspectRatioForBytes(bytes),
      );
  pushAddClipUndo(ref, id);
}
