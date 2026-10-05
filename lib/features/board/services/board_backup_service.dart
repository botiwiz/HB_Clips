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
/// Deliberately operates on whichever board is passed in, read via the
/// same one-shot `ref.read(...).valueOrNull` pattern `_exportPdfFile`
/// already uses - callers switch boards first (via the existing board
/// switcher) rather than this function taking a selection of its own.
Future<Uint8List> exportBoardBackup(WidgetRef ref, String boardId) async {
  final boardName = (ref.read(boardsProvider).valueOrNull ?? [])
      .firstWhere((b) => b.id == boardId)
      .name;
  final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
  final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
  final connectors = ref.read(activeConnectorsProvider).valueOrNull ?? [];
  final strokes = ref.read(boardStrokesProvider).valueOrNull ?? [];
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

/// Counts from one `.hbbackup` import, shown to the user in a summary
/// dialog - mirrors `PurImportSummary`'s role for `.pur` imports.
class BoardBackupSummary {
  final String newBoardId;
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

  const BoardBackupSummary({
    required this.newBoardId,
    required this.boardName,
    required this.framesImported,
    required this.clipsImported,
    required this.connectorsImported,
    required this.strokesImported,
    required this.imagesRestored,
    required this.imagesMissing,
  });
}

/// Imports a `.hbbackup` file's raw [bytes] as a brand-new board -
/// never overwrites or merges into an existing one. Every id in the
/// archive is freshly regenerated (frames, clips, connectors, strokes),
/// with every cross-reference (a clip's `groupId`/`frameId`, a
/// connector's `fromClipId`/`toClipId`, a stroke's `clipId`) remapped
/// through the id this import just minted for it - see the inline id
/// maps below. Reuses the exact same repository primitives Alt-drag-
/// duplicate/Ctrl+C-V already rely on (`ClipsRepository.duplicateClip`,
/// `FramesRepository.duplicateFrame`) rather than any new "restore"
/// method - both already copy every field of a passed-in `BoardClip`/
/// `FrameRow` except `boardId`/`id`/`groupId`/`frameId`, which is
/// exactly what's needed here too, just fed a `BoardClip`/`FrameRow`
/// reconstructed from the manifest instead of a live board object.
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

  final newBoardId = _uuid.v4();
  await ref
      .read(boardsRepositoryProvider)
      .createBoard(newBoardId, manifest.boardName);

  final frameIdMap = <String, String>{};
  for (final f in manifest.frames) {
    final newId = _uuid.v4();
    await ref
        .read(framesRepositoryProvider)
        .duplicateFrame(
          FrameRow(
            id: f.id,
            boardId: newBoardId,
            name: f.name,
            x: f.x,
            y: f.y,
            width: f.width,
            height: f.height,
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
          c.toBoardClip(boardId: newBoardId, localFilePath: newLocalFilePath),
          newId: newId,
          groupId: newGroupId,
          frameId: newFrameId,
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
          boardId: newBoardId,
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
          boardId: newBoardId,
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
    newBoardId: newBoardId,
    boardName: manifest.boardName,
    framesImported: frameIdMap.length,
    clipsImported: clipIdMap.length,
    connectorsImported: connectorsImported,
    strokesImported: strokesImported,
    imagesRestored: imagesRestored,
    imagesMissing: imagesMissing,
  );
}
