import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local_blob_store.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/clips_repository.dart';
import '../controllers/undo_controller.dart';
import 'image_size_service.dart';
import 'link_preview_service.dart';
import 'remote_image_fetch_service.dart';

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

/// Creates a link clip for [url] centered at [boardCenter], then kicks off
/// (but doesn't await) a best-effort fetch of the page's title/thumbnail -
/// the clip exists and is undoable immediately, so a paste never blocks on
/// a network round-trip; the title/thumbnail fill in shortly after if the
/// fetch succeeds, or the clip just keeps showing its hostname + a generic
/// link icon if it doesn't (no retry - matches this codebase's
/// established "best-effort, fail quiet" convention for remote fetches).
Future<void> addLinkClipFromUrl(
  WidgetRef ref, {
  required String url,
  required Offset boardCenter,
}) async {
  final id = _uuid.v4();
  final boardId = ref.read(currentBoardIdProvider);
  // Captured synchronously, before any `await`, so the long-running
  // background fetch below never holds onto `ref` itself across an async
  // gap - these repository/store objects are long-lived (tied to the
  // ProviderScope/database, not this gesture's widget), so using them
  // after the triggering widget unmounts is safe in a way re-reading
  // `ref` later would not be.
  final clipsRepo = ref.read(clipsRepositoryProvider);
  final blobStore = ref.read(localBlobStoreProvider);

  await clipsRepo.addLinkClip(
    id: id,
    boardId: boardId,
    linkUrl: url,
    x: boardCenter.dx - kDefaultLinkClipWidth / 2,
    y: boardCenter.dy - kDefaultLinkClipHeight / 2,
  );
  pushAddClipUndo(ref, id);

  unawaited(
    _fetchAndApplyLinkMetadata(
      clipsRepo: clipsRepo,
      blobStore: blobStore,
      id: id,
      url: url,
    ),
  );
}

Future<void> _fetchAndApplyLinkMetadata({
  required ClipsRepository clipsRepo,
  required LocalBlobStore blobStore,
  required String id,
  required String url,
}) async {
  final pageUri = Uri.tryParse(url);
  if (pageUri == null) return;

  final metadata = await fetchLinkPreviewMetadata(pageUri);
  String? thumbnailPath;
  if (metadata.imageUri != null) {
    final image = await fetchImageBytes(metadata.imageUri!);
    if (image != null) {
      final square = squareThumbnailBytes(image.bytes);
      if (square != null) {
        thumbnailPath = await blobStore.writeBytes(square, extension: '.png');
      }
    }
  }
  if (metadata.title == null && thumbnailPath == null) return;
  await clipsRepo.updateLinkMetadata(
    id,
    title: metadata.title,
    thumbnailPath: thumbnailPath,
  );
}
