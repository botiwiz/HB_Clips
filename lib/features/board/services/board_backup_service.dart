import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart' show kBoardBackupFormatVersion;
import '../../../data/backup/board_backup_manifest.dart';
import '../../../data/local/database.dart' show FrameRow;
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';

const _uuid = Uuid();

/// Reads everything the given [boardId] currently shows (frames, active
/// - never binned - clips, connectors, strokes, plus every image clip's
/// real bytes via [LocalBlobStore]) and packs it into one self-contained
/// `.hbbackup` archive's bytes, ready to hand to a file-save dialog.
///
/// Reads every board-scoped collection directly from its repository by
/// [boardId] (`watchXxx(boardId).first` - a one-shot read of a Drift
/// stream query's current snapshot, which it emits immediately on
/// subscription), NOT via `boardFramesProvider`/`activeClipsProvider`/
/// `activeConnectorsProvider`/`boardStrokesProvider` - those providers
/// are all scoped to `currentBoardIdProvider` (whichever board is
/// currently open in the UI), not to this function's [boardId]
/// parameter. Using them here was a real, shipped bug: exporting every
/// board in a loop (the old auto-backup, and now `saveAllBoardsToBackupFolder`
/// in `backup_folder_service.dart`) produced one correctly-named
/// `.hbbackup` file per board, but every single one actually contained
/// whichever board happened to be open at the time, not its own content.
/// Only a single export of the currently-open board (the old manual
/// "Save") ever happened to look correct, which is why this went
/// unnoticed until the multi-board Save-all/auto-backup path actually
/// exercised a [boardId] different from the active one.
Future<Uint8List> exportBoardBackup(WidgetRef ref, String boardId) async {
  final boardName = (ref.read(boardsProvider).valueOrNull ?? [])
      .firstWhere((b) => b.id == boardId)
      .name;
  final frames = await ref
      .read(framesRepositoryProvider)
      .watchFrames(boardId)
      .first;
  final clips = await ref
      .read(clipsRepositoryProvider)
      .watchActiveClips(boardId)
      .first;
  final connectors = await ref
      .read(connectorsRepositoryProvider)
      .watchConnectors(boardId)
      .first;
  final strokes = await ref
      .read(strokesRepositoryProvider)
      .watchStrokes(boardId)
      .first;
  final blobStore = ref.read(localBlobStoreProvider);

  final blobsByClipId = <String, Uint8List>{};
  for (final clip in clips) {
    if (clip.type != ClipType.image || clip.localFilePath == null) continue;
    final bytes = await blobStore.readBytes(clip.localFilePath!);
    if (bytes != null) blobsByClipId[clip.id] = bytes;
  }

  final packageInfo = await PackageInfo.fromPlatform();
  final manifest = BoardBackupManifest(
    formatVersion: kBoardBackupFormatVersion,
    appVersion: packageInfo.version,
    exportedAt: DateTime.now(),
    boardName: boardName,
    boardId: boardId,
    frames: frames.map(BackupFrame.fromRow).toList(),
    clips: clips
        .map(
          (c) =>
              BackupClip.fromModel(c, hasBlob: blobsByClipId.containsKey(c.id)),
        )
        .toList(),
    connectors: connectors.map(BackupConnector.fromModel).toList(),
    strokes: strokes.map(BackupStroke.fromModel).toList(),
  );
  return encodeBackupArchive(manifest, blobsByClipId);
}

/// Counts from one `.hbbackup` import/update, shown to the user in a Load
/// summary dialog - mirrors `PurImportSummary`'s role for `.pur` imports.
class BoardBackupSummary {
  final String boardId;
  final String boardName;
  final int framesImported;
  final int clipsImported;
  final int connectorsImported;
  final int strokesImported;

  /// Image clips whose bytes were embedded in the archive and were
  /// successfully written back out to a fresh local blob.
  final int imagesRestored;

  /// Image clips that had bytes embedded at export time
  /// (`BackupClip.hasBlob`) but whose entry is missing from this
  /// specific archive - a genuine "this file's own image data is
  /// gone," not "this clip never had an image."
  final int imagesMissing;

  /// True if this overwrote an existing board in place
  /// ([updateBoardFromBackup]), false if it created a brand-new one
  /// ([importBoardBackup]) - lets Load's summary dialog report
  /// "created N, updated M" instead of just a flat count.
  final bool wasUpdate;

  const BoardBackupSummary({
    required this.boardId,
    required this.boardName,
    required this.framesImported,
    required this.clipsImported,
    required this.connectorsImported,
    required this.strokesImported,
    required this.imagesRestored,
    required this.imagesMissing,
    required this.wasUpdate,
  });
}

/// Imports a `.hbbackup` file's raw [bytes] as a brand-new board -
/// never overwrites or merges into an existing one. Creates the board
/// row (minting a fresh id if the manifest has none - a legacy v1 file -
/// or reusing its embedded [BoardBackupManifest.boardId] otherwise, so
/// a later re-Load of this same export can recognize it via
/// [updateBoardFromBackup] instead of creating a duplicate), then
/// populates it via [_populateBoardFromManifest].
///
/// Callers are expected to have already confirmed (e.g. via
/// `backup_folder_service.dart`'s `decideLoadAction`) that no board
/// with this id already exists - this is a precondition, not
/// re-checked defensively here.
///
/// Throws a [FormatException] (from `decodeBackupArchive`) for
/// anything that isn't a valid, readable `.hbbackup` file - callers
/// are expected to catch this and show its message directly.
Future<BoardBackupSummary> importBoardBackup(
  WidgetRef ref,
  Uint8List bytes,
) async {
  final decoded = decodeBackupArchive(bytes);
  final manifest = decoded.manifest;

  final boardId = manifest.boardId ?? _uuid.v4();
  await ref
      .read(boardsRepositoryProvider)
      .createBoard(boardId, manifest.boardName);

  return _populateBoardFromManifest(ref, boardId, decoded, wasUpdate: false);
}

/// Overwrites an existing board ([existingBoardId]) in place from a
/// newer `.hbbackup` export of the same board (matched by
/// [BoardBackupManifest.boardId] - see `backup_folder_service.dart`'s
/// `decideLoadAction`): renames it to the manifest's current name,
/// wipes its contents ([BoardsRepository.wipeBoardContents]), then
/// repopulates it via [_populateBoardFromManifest] using the *same*
/// board id so frames/clips/etc regenerate fresh under the existing
/// board rather than spawning a duplicate one.
///
/// Throws a [FormatException] for the same reasons [importBoardBackup]
/// does.
Future<BoardBackupSummary> updateBoardFromBackup(
  WidgetRef ref,
  String existingBoardId,
  Uint8List bytes,
) async {
  final decoded = decodeBackupArchive(bytes);
  await ref
      .read(boardsRepositoryProvider)
      .renameBoard(existingBoardId, decoded.manifest.boardName);
  await ref.read(boardsRepositoryProvider).wipeBoardContents(existingBoardId);
  return _populateBoardFromManifest(
    ref,
    existingBoardId,
    decoded,
    wasUpdate: true,
  );
}

/// Shared by [importBoardBackup] (a fresh board) and
/// [updateBoardFromBackup] (an existing board just wiped clean): builds
/// every frame/clip/connector/stroke under [boardId] from [decoded],
/// with every cross-reference (a clip's `groupId`/`frameId`, a
/// connector's `fromClipId`/`toClipId`, a stroke's `clipId`) remapped
/// through the id this pass mints for it - see the inline id maps
/// below. Reuses the exact same repository primitives Alt-drag-
/// duplicate/Ctrl+C-V already rely on (`ClipsRepository.duplicateClip`,
/// `FramesRepository.duplicateFrame`) rather than any new "restore"
/// method - both already copy every field of a passed-in `BoardClip`/
/// `FrameRow` except `boardId`/`id`/`groupId`/`frameId`, which is
/// exactly what's needed here too, just fed a `BoardClip`/`FrameRow`
/// reconstructed from the manifest instead of a live board object.
Future<BoardBackupSummary> _populateBoardFromManifest(
  WidgetRef ref,
  String boardId,
  DecodedBackupArchive decoded, {
  required bool wasUpdate,
}) async {
  final manifest = decoded.manifest;
  final frameIdMap = <String, String>{};
  for (final f in manifest.frames) {
    final newId = _uuid.v4();
    await ref
        .read(framesRepositoryProvider)
        .duplicateFrame(
          FrameRow(
            id: f.id,
            boardId: boardId,
            name: f.name,
            x: f.x,
            y: f.y,
            width: f.width,
            height: f.height,
            sortOrder: 0,
            backgroundColorHex: f.backgroundColorHex,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          newId: newId,
        );
    frameIdMap[f.id] = newId;
  }

  final clipIdMap = <String, String>{};
  final groupIdMap = <String, String>{};
  final blobStore = ref.read(localBlobStoreProvider);
  var imagesRestored = 0;
  var imagesMissing = 0;
  final orderedClips = [...manifest.clips]
    ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  for (final c in orderedClips) {
    String? newLocalFilePath;
    if (c.type == ClipType.image) {
      final blobBytes = decoded.blobsByClipId[c.id];
      if (blobBytes != null) {
        newLocalFilePath = await blobStore.writeBytes(blobBytes);
        imagesRestored++;
      } else if (c.hasBlob) {
        imagesMissing++;
      }
    }
    final newGroupId = c.groupId == null
        ? null
        : groupIdMap.putIfAbsent(c.groupId!, _uuid.v4);
    final newFrameId = c.frameId == null ? null : frameIdMap[c.frameId];
    final newId = _uuid.v4();
    await ref
        .read(clipsRepositoryProvider)
        .duplicateClip(
          c.toBoardClip(boardId: boardId, localFilePath: newLocalFilePath),
          newId: newId,
          groupId: newGroupId,
          frameId: newFrameId,
          // Backups don't carry kanban-board/swimlane data this round (see
          // Kanban plan's "explicitly out of scope" list) - a restored
          // clip always lands with no swimlane membership.
          swimlaneId: null,
        );
    clipIdMap[c.id] = newId;
  }

  var connectorsImported = 0;
  for (final conn in manifest.connectors) {
    final from = clipIdMap[conn.fromClipId];
    final to = clipIdMap[conn.toClipId];
    if (from == null || to == null) continue; // defensive - shouldn't happen
    await ref
        .read(connectorsRepositoryProvider)
        .addConnector(
          id: _uuid.v4(),
          boardId: boardId,
          fromClipId: from,
          fromSide: conn.fromSide,
          toClipId: to,
          toRelX: conn.toRelX,
          toRelY: conn.toRelY,
        );
    connectorsImported++;
  }

  var strokesImported = 0;
  for (final s in manifest.strokes) {
    final mappedClipId = s.clipId == null ? null : clipIdMap[s.clipId];
    if (s.clipId != null && mappedClipId == null) {
      continue; // defensive - shouldn't happen
    }
    await ref
        .read(strokesRepositoryProvider)
        .addStroke(
          id: _uuid.v4(),
          boardId: boardId,
          clipId: mappedClipId,
          colorHex: s.colorHex,
          strokeWidth: s.strokeWidth,
          points: s.points,
          dashed: s.dashed,
          arrowEnd: s.arrowEnd,
        );
    strokesImported++;
  }

  return BoardBackupSummary(
    boardId: boardId,
    wasUpdate: wasUpdate,
    boardName: manifest.boardName,
    framesImported: frameIdMap.length,
    clipsImported: clipIdMap.length,
    connectorsImported: connectorsImported,
    strokesImported: strokesImported,
    imagesRestored: imagesRestored,
    imagesMissing: imagesMissing,
  );
}
